#!/bin/bash
## Addresses of LB
address=`cat ~/tmp/to_aws/files/lb.address | awk '{print $4}'`
address=`dig +short $address | head -1`
echo $address

echo ""
echo ""
echo ""
echo "Add to your hosts file following record: $address myapp.daliaresearch.com"
echo "Then point your browser to http://myapp.daliaresearch.com to test the application hosted on this platform"
echo ""
echo "Files generated by this script are located in ./to_aws/files."
echo "PEM keys for all servers are in ./to_aws/keys"
echo ""
echo ""
