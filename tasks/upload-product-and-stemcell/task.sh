#!/bin/bash

set -eu

if [[ -n "$NO_PROXY" ]]; then
  echo "$OM_IP $OPS_MGR_HOST" >> /etc/hosts
fi

STEMCELL_VERSION=`cat ./s3-ert-metadata/metadata.json | jq --raw-output '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Version'`

if [ -n "$STEMCELL_VERSION" ]; then
  diagnostic_report=$(
    om-linux \
      --target https://$OPS_MGR_HOST \
      --username $OPS_MGR_USR \
      --password $OPS_MGR_PWD \
      --skip-ssl-validation \
      curl --silent --path "/api/v0/diagnostic_report"
  )

  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )

  if [[ -z "$stemcell" ]]; then
    echo "Downloading stemcell from S3 $STEMCELL_VERSION"
    stemcellname="bosh-stemcell-$STEMCELL_VERSION-vsphere-esxi-ubuntu-trusty-go_agent.tgz"
    echo "Stemcell name" $stemcellname
    echo "S3 Bucket" $s3_bucket    

    dateValue=`date -R`
    contentType="application/x-compressed-tar"
    resource="/${s3_bucket}/stemcells/${stemcell}"
    stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
    signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3_secret_access_key} -binary | base64`

    curl  -H "Host: ${s3_bucket}.s3.amazonaws.com" \
     -H "Date: ${dateValue}" \
     -H "Content-Type: ${contentType}" \
     -H "Authorization: AWS ${s3_access_key_id}:${signature}" \
     https://${s3_bucket}.s3.amazonaws.com/${stemcellname} -o $stemcellname


    #pivnet-cli login --api-token="$PIVNET_API_TOKEN"
    #pivnet-cli download-product-files -p stemcells -r $STEMCELL_VERSION -g "*${IAAS}*" --accept-eula

    SC_FILE_PATH=`find ./ -name *.tgz`
    echo "Stemcell found $SC_FILE_PATH" 
    ls -lart $SC_FILE_PATH

    if [ ! -f "$SC_FILE_PATH" ]; then
      echo "Stemcell file not found!"
      exit 1
    fi

    om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH

    echo "Removing downloaded stemcell $STEMCELL_VERSION"
    rm $SC_FILE_PATH
  fi
fi

FILE_PATH=`find ./s3-ert-binary -name *.pivotal`
om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k --request-timeout 3600 upload-product -p $FILE_PATH

echo "Removing downloaded ERT Binary"
rm $FILE_PATH
