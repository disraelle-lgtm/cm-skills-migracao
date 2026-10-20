c:
CD\SYSPDV
set isc_user=SYSDBA 
set isc_password=masterkey
gfix -v -f -user sysdba -password masterkey SYSPDV_SRV.FDB
gfix -m -f -i -user sysdba -password masterkey SYSPDV_SRV.FDB
gbak -b -v -i -g -l -user sysdba -password masterkey SYSPDV_SRV.FDB SYSPDV_SRV.GBK
ren SYSPDV_SRV.FDB SYSPDV_SRV_OLD.FDB
GBAK -c -v -i -user sysdba -password masterkey SYSPDV_SRV.GBK SYSPDV_SRV.FDB
break
