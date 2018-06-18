#!/bin/bash

set -ex

if [ "$ORACLEV" = "11.2" ]; then
    export LONGV="11.2.0.4.0"
fi
if [ "$ORACLEV" = "12.2" ]; then
    export LONGV="12.2.0.1.0"
fi

if [ -n "$ORACLEV" ]; then
    echo "Install Oracle SDK $ORACLEV"
    mkdir /etc/oracle
    mkdir -p /usr/lib/oracle/$ORACLEV/client/bin
    mkdir -p /usr/lib/oracle/$ORACLEV/client/lib
    mkdir -p /usr/include/oracle/$ORACLEV/client
    mkdir -p /usr/share/oracle/$ORACLEV/client
    pushd `pwd`
    cd /usr/lib/oracle
    for i in "basic" "sdk" "sqlplus"; do
        # Repo intended for Dockerfiles, see https://github.com/bumpx/oracle-instantclient/blob/master/README.md
        wget --quiet https://github.com/bumpx/oracle-instantclient/raw/master/instantclient-$i-linux.x64-$LONGV.zip
    done
    for i in `ls *zip`; do unzip $i; done
fi
if [ "$ORACLEV" = "12.2" ]; then
    echo "# Contents of instantclient-basic-linux.x64-$LONGV.zip"
    find instantclient_12_2
    mv instantclient_12_2/adrci $ORACLEV/client/bin/
    mv instantclient_12_2/genezi $ORACLEV/client/bin/
    mv instantclient_12_2/uidrvci $ORACLEV/client/bin/
    mv instantclient_12_2/{libclntshcore.so.12.1,libclntsh.so.12.1,libipc1.so,libmql1.so,libnnz12.so,libocci.so.12.1,libociei.so,libocijdbc12.so,libons.so,liboramysql12.so,ojdbc8.jar,xstreams.jar} $ORACLEV/client/lib/
    echo "# Contents of instantclient-sqlplus-linux.x64-$LONGV.zip"
    mv instantclient_12_2/sqlplus $ORACLEV/client/bin/
    mv instantclient_12_2/glogin.sql instantclient_12_2/libsqlplus.so instantclient_12_2/libsqlplusic.so $ORACLEV/client/lib/
    echo "# Contents of instantclient-sdk-linux.x64-$LONGV.zip"
    mv instantclient_12_2/sdk/include/*h /usr/include/oracle/$ORACLEV/client/
    mv instantclient_12_2/sdk/demo/* /usr/share/oracle/$ORACLEV/client/
    mv instantclient_12_2/sdk/ott /usr/share/oracle/$ORACLEV/client/
    mv instantclient_12_2/sdk/ottclasses.zip $ORACLEV/client/lib/ottclasses.zip
    ln -s libclntshcore.so.12.1 $ORACLEV/client/lib/libclntshcore.so
    ln -s libclntsh.so.12.1 $ORACLEV/client/lib/libclntsh.so
    ln -s libocci.so.12.1 $ORACLEV/client/lib/libocci.so
    echo "# FYI What wasnt moved from Oracle zip files:"
    find instantclient_12_2
    echo "# Clean up"
    rm -rf instantclient_12_2
fi
if [ "$ORACLEV" = "11.2" ]; then
    echo "# Contents of instantclient-basic-linux.x64-$LONGV.zip"
    mv instantclient_11_2/adrci $ORACLEV/client/bin/
    mv instantclient_11_2/genezi $ORACLEV/client/bin/
    mv instantclient_11_2/uidrvci $ORACLEV/client/bin/
    mv instantclient_11_2/{libclntsh.so.11.1,libnnz11.so,libocci.so.11.1,libociei.so,libocijdbc11.so,ojdbc5.jar,ojdbc6.jar,xstreams.jar} $ORACLEV/client/lib/
    echo "# Contents of instantclient-sqlplus-linux.x64-$LONGV.zip"
    mv instantclient_11_2/sqlplus $ORACLEV/client/bin/
    mv instantclient_11_2/glogin.sql instantclient_11_2/libsqlplus.so instantclient_11_2/libsqlplusic.so $ORACLEV/client/lib/
    echo "# Contents of instantclient-sdk-linux.x64-$LONGV.zip"
    mv instantclient_11_2/sdk/include/*h /usr/include/oracle/$ORACLEV/client/
    mv instantclient_11_2/sdk/demo/* /usr/share/oracle/$ORACLEV/client/
    mv instantclient_11_2/sdk/ott /usr/share/oracle/$ORACLEV/client/
    mv instantclient_11_2/sdk/ottclasses.zip $ORACLEV/client/lib/ottclasses.zip
    ln -s libclntsh.so.11.1 $ORACLEV/client/lib/libclntsh.so
    ln -s libocci.so.11.1 $ORACLEV/client/lib/libocci.so
    echo "# FYI What wasnt moved from Oracle zip files:"
    find instantclient_11_2
    echo "# Clean up"
    rm -rf instantclient_11_2
fi
if [ -n "$ORACLEV" ]; then
    echo "# Place paths in ENV"
    echo "export ORACLE_HOME=/usr/lib/oracle/$ORACLEV/client" >> /etc/profile.d/oracle.sh
    echo "export PATH=\$PATH:\$ORACLE_HOME/bin" >> /etc/profile.d/oracle.sh
    echo "export TNS_ADMIN=/etc/oracle" >> /etc/profile.d/oracle.sh
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib" >> /etc/profile.d/oracle.sh
    echo "/usr/lib/oracle/$ORACLEV/client/lib" > /etc/ld.so.conf.d/oracle-instantclient.conf
    echo "# Make sure stuff is +x"
    chmod +x $ORACLEV/client/bin/*
    ldconfig
    popd
    cat /etc/profile
fi
