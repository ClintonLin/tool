#!/bin/bash
while read line
do
    su - i2kuser -c "psql -p 1525 -d dmudb -U dmuuser -c \"select ipaddress from tbl_resource where dn = (select deviceid from cie_support_nodeinfo where name = '$line');\"" | grep "10."
done < /opt/huawei/cie/mq/wpz_analyse/msg_stock/2016_01_13/bmuname.list
