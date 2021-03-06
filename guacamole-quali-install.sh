#!/bin/bash
set -e
set -o pipefail
set -o nounset

## Logging to file /etc/guacamole/log.out

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>~/log.out 2>&1

echo "QualiX Script - Starting QualiX installation script - modified version - no tls 1.2 support" 
##														PARAMETERS 
GUACAMOLE_VERSION="0.9.14"
GUACAMOLE_WAR_NAME="remote"
QUALI_AUTH_MAIN_CLASS="net.sourceforge.guacamole.net.auth.quali.QualiProvider"
GUACAMOLE_PROPERTIES="guacamole.properties"
GUACAMOLE_HOME_DIR="/usr/share/tomcat/.guacamole/"
QUALI_AUTH_PACK_NAME="qualix-0.9.14"
S3LOCATION="https://s3.amazonaws.com/quali-prod-binaries/"$QUALI_AUTH_PACK_NAME".tar.gz"
HTTP_PORT="80"
HTTPS_PORT="443"
KEYSTORE_PASS="123123"

#Make sure all yum transaction are complete
# removed: -y --cleanup-only
yum-complete-transaction -y --cleanup-only
yum clean all
yum makecache

echo "Prerequisite: epel-release"
yum -y install epel-release

if [ $? -ne 0 ]
then
    echo "Epel-release installation failed"
    sed -i "s~#baseurl=~baseurl=~g" /etc/yum.repos.d/epel.repo
    sed -i "s~mirrorlist=~#mirrorlist=~g" /etc/yum.repos.d/epel.repo
    yum -y install epel-release
fi

echo "Prerequisite: wget"
yum -y install wget

#source https://deviantengineer.com/2015/02/guacamole-centos7/

# echo "QualiX Script - FreeRDP Prerequisite" 

# yum install -y gcc cmake openssl-devel libX11-devel libXext-devel libXinerama-devel libXcursor-devel \
# libXi-devel libXdamage-devel libXv-devel libxkbfile-devel alsa-lib-devel cups-devel ffmpeg-devel glib2-devel unzip wget nano

# echo "QualiX Script - Get FreeRDP sources" 

# wget https://github.com/FreeRDP/FreeRDP/archive/stable-1.1.zip

# unzip stable-1.1.zip

# cd FreeRDP-stable-1.1/

# echo "QualiX Script - Building FreeRDP sources" 

# cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SSE2=ON .
 
# make
 
# sudo make install

# xfreerdp /version


echo "QualiX Script - Guacamole Prerequisite" 

wget -O /etc/yum.repos.d/home:felfert.repo http://download.opensuse.org/repositories/home:/felfert/CentOS_7/home:felfert.repo

echo "wget home:felfert.repo"

yum -y install cairo-devel freerdp-devel gcc java-1.8.0-openjdk.x86_64 libguac libguac-client-rdp libguac-client-ssh libguac-client-vnc \
libjpeg-turbo-devel libpng-devel libssh2-devel libtelnet-devel libvncserver-devel libvorbis-devel libwebp-devel openssl-devel pango-devel \
pulseaudio-libs-devel freerdp-plugins dejavu-sans-mono-fonts.noarch tomcat tomcat-admin-webapps tomcat-webapps uuid-devel python-pip libtool

pip install --upgrade pip
pip install boto3

echo "QualiX Script - Guacd Install" 
mkdir -p ~/guacamole && cd ~/
	 
wget -q https://github.com/apache/incubator-guacamole-server/archive/"$GUACAMOLE_VERSION".tar.gz -O $GUACAMOLE_VERSION.tar.gz
tar -xzf $GUACAMOLE_VERSION.tar.gz
cd guacamole-server-$GUACAMOLE_VERSION
##generate the configuration files
autoreconf -fi 
./configure --with-init-dir=/etc/init.d
make
make install
#ldconfig

#echo "/usr/local/lib
#	/usr/local/lib/freerdp
#	/usr/local/lib64" > /etc/ld.so.conf.d/freerdp.conf

#echo "QualiX Script - libguac-client-rdp configuration results"
#ldd -r /usr/local/lib/libguac-client-rdp.so

ldconfig

echo "QualiX Script - guacamole client" 
mkdir -p /var/lib/guacamole
cd /var/lib/guacamole/
wget https://sourceforge.net/projects/guacamole/files/current/binary/guacamole-"$GUACAMOLE_VERSION".war -O $GUACAMOLE_WAR_NAME.war
chmod -R 777 $GUACAMOLE_WAR_NAME.war
cp /var/lib/guacamole/$GUACAMOLE_WAR_NAME.war /var/lib/tomcat/webapps/$GUACAMOLE_WAR_NAME.war
rm -rf /usr/lib64/freerdp/guacdr.so
ln -sf /usr/local/lib/freerdp/guacdr.so /usr/lib64/freerdp/

# mkdir /usr/local/lib64/freerdp/
# ln -sf /usr/local/lib/freerdp/guacdr-client.so /usr/local/lib64/freerdp
# ln -sf /usr/local/lib/freerdp/guacsnd-client.so /usr/local/lib64/freerdp

echo "QualiX Script - Configure Guacamole" 

mkdir -p $GUACAMOLE_HOME_DIR
mkdir -p $GUACAMOLE_HOME_DIR/{extensions,lib}
touch $GUACAMOLE_HOME_DIR/$GUACAMOLE_PROPERTIES

echo "	# /etc/guacamole/guacamole.properties
	# Hostname and port of guacamole proxy
	guacd-hostname: localhost
	guacd-port:     4822

	lib-directory: /etc/guacamole

	# Auth provider class (authenticates user/pass combination, needed if using the provided login screen)
	auth-provider: $QUALI_AUTH_MAIN_CLASS" > $GUACAMOLE_HOME_DIR/$GUACAMOLE_PROPERTIES

echo "QualiX Script - Creating the /usr/share/tomcat/.guacamole/files/ and giving it permissions"
mkdir -p $GUACAMOLE_HOME_DIR/files/
chmod -R 777 $GUACAMOLE_HOME_DIR/
chmod -R 777 $GUACAMOLE_HOME_DIR/files/
	
echo "QualiX Script - Deploy guacamole-auth-quali" 

cd ~
mkdir -p qualix
cd qualix

#taking the package from the current directory if it exists - as artifact, else getting it from S3.
echo "QualiX Script - getting our guacamole authentication plugin" 
if [ -e /root/$QUALI_AUTH_PACK_NAME".tar.gz" ]; then
	echo "using the local file"
	cp /root/$QUALI_AUTH_PACK_NAME".tar.gz" $QUALI_AUTH_PACK_NAME.tar.gz
else
	echo "getting plugin from S3"
	wget -q $S3LOCATION -O $QUALI_AUTH_PACK_NAME.tar.gz	
fi

tar -xzf $QUALI_AUTH_PACK_NAME.tar.gz
cd guacamole-auth-quali-$GUACAMOLE_VERSION
cp guacamole-auth-quali-$GUACAMOLE_VERSION.jar $GUACAMOLE_HOME_DIR/extensions/
cd resources
for f in *.*; do chmod +x $f ;  done
for f in *.*; do cp $f / ;  done


echo "QualiX Script - Redirect ports for tomcat" 
iptables -t nat -A PREROUTING -p tcp --dport $HTTP_PORT -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --dport $HTTPS_PORT -j REDIRECT --to-port 8443
iptables-save > /etc/iptables.conf
echo "iptables-restore < /etc/iptables.conf" >> /etc/rc.local
chmod +x /etc/rc.d/rc.local

echo "QualiX Script - Creating the certificate for SSL"
# https://www.sslshopper.com/article-how-to-create-a-self-signed-certificate-using-java-keytool.html
cd /usr/share/tomcat
rm -f .keystore
keytool -genkeypair -noprompt -alias Tomcat -keyalg RSA -dname "CN=quali, OU=quali, O=quali, L=quali, S=quali, C=IL" -keystore .keystore -storepass $KEYSTORE_PASS -keypass $KEYSTORE_PASS -validity 365000
 
echo "QualiX Script - Change /etc/tomcat/server.xml"
cd /etc/tomcat
sed -i '/<Service name="Catalina">/a <Connector port="8443" protocol="org.apache.coyote.http11.Http11Protocol" maxThreads="150" SSLEnabled="true" scheme="https" secure="true" keystoreFile="${user.home}/.keystore" keystorePass="'$KEYSTORE_PASS'" clientAuth="false" sslProtocol="TLS" />' server.xml

echo "QualiX Script - Cleanups"
cd ~
rm -rf guacamole*

echo "QualiX Script - Enable all services" 
#http://www.davidghedini.com/pg/entry/install_tomcat_7_on_centos

#Redirect Tomcat root to the guacamole application
redirect='<% response.sendRedirect("/remote"); %>'
sed -i '1s|^|'"$redirect"'\n|' /var/lib/tomcat/webapps/ROOT/index.jsp

chkconfig --level 234 tomcat on
chkconfig --add guacd
chkconfig --level 234 guacd on
systemctl enable tomcat
systemctl start tomcat
systemctl enable guacd
systemctl start guacd

echo "QualiX Script - Finish to install" 


echo "QualiX Script - Starting QualiX validations" 

## do not exit on error
set +e

## validate Tomcat
systemctl status tomcat | grep 'running' > /dev/null 2>&1
if [ $? != 0 ]
then
	echo "ERROR - Tomcat Web service is not running, please see QualiX installation log for more details." 
	systemctl status tomcat -l
	exit 1
fi

sleep 1m

## Validate guacamole
wget https://localhost:8443/remote/api/languages --no-check-certificate --content-on-error > /dev/null 2>&1
if [ $? != 0 ]
then
	echo "ERROR - Failed to retrieve Guacamole languages, please see QualiX installation log for more details." 
	wget https://localhost:8443/remote/api/languages --no-check-certificate
	echo "DEBUG - Tomcat webapps: "
	ls -l /var/lib/tomcat/webapps/
	exit 1
fi