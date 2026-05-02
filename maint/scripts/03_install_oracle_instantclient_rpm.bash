#!/bin/bash

set -ex

if [ "$ORACLEV" = "latest" ]; then
   # Get lastest RPMs from Oracle Client permanent links
   for i in "basic" "devel" "sqlplus"; do
      wget --quiet "https://download.oracle.com/otn_software/linux/instantclient/oracle-instantclient-$i-linuxx64.rpm"
   done

   # Convert rpm to deb pkgs
   alien -k *.rpm
   dpkg -i *.deb

   find /usr/lib/oracle

   ORACLEV=$(ls /usr/lib/oracle | sed 's/\///')

   echo "# Place paths in ENV"
   echo "export ORACLE_HOME=/usr/lib/oracle/$ORACLEV/client64" >> /etc/profile.d/oracle.sh
   echo "export PATH=\$PATH:\$ORACLE_HOME/bin" >> /etc/profile.d/oracle.sh
   echo "export TNS_ADMIN=/etc/oracle" >> /etc/profile.d/oracle.sh
   echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib" >> /etc/profile.d/oracle.sh
   echo "/usr/lib/oracle/$ORACLEV/client64/lib" > /etc/ld.so.conf.d/oracle-instantclient.conf
   echo "# Make sure stuff is +x"
   chmod +x /usr/lib/oracle/$ORACLEV/client64/bin/*
   ldconfig
   cat /etc/profile
fi
