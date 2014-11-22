#!/bin/bash -x

currHostName=`hostname`
echo "test "
export date1=$(date +"%s")
documentRoot=$(ctx source node properties docRoot)
ctx logger info "${currHostName}:$0 :documentRoot ${documentRoot}"

databaseName=$(ctx source node properties dbName)
ctx logger info "${currHostName}:$0 :databaseName ${databaseName}"

dbUsername=$(ctx source node properties dbUserName)
ctx logger info "${currHostName}:$0 :dbUsername ${dbUsername}"

dbPassword=$(ctx source node properties dbUserPassword)
ctx logger info "${currHostName}:$0 :dbPassword ${dbPassword}"

dbPort=$(ctx target node properties port)
ctx logger info "${currHostName}:$0 :dbPort ${dbPort}"

dbHost=$(ctx target instance host_ip)
ctx logger info "${currHostName}:$0 :dbHost ${dbHost}"

drupalImageURL=$(ctx source node properties drupalImageURL)
ctx logger info "${currHostName}:$0 :drupalImageURL ${drupalImageURL}"


# args:
# $1 the error code of the last command (should be explicitly passed)
# $2 the message to print in case of an error
# 
# an error message is printed and the script exists with the provided error code
function error_exit {
	echo "$2 : error code: $1"
	exit ${1}
}


export PATH=$PATH:/usr/sbin:/sbin || error_exit $? "Failed on: export PATH=$PATH:/usr/sbin:/sbin"

ctx logger info "${currHostName}:$0 :Deleting ${documentRoot}/index.html ..."
sudo rm -rf $documentRoot/index.html
ctx logger info "${currHostName}:$0 :Deleting ${documentRoot}/index.php ..."
sudo rm -rf $documentRoot/index.php

pushd /tmp
mkdir tmpZipFolder
cd tmpZipFolder
zipLocation=/tmp/tmpZipFolder
ctx logger info "${currHostName}:$0 :wgetting ${drupalImageURL}"
drupalZip=drupal.zip
wget -O $drupalZip $drupalImageURL
contentLevel=`unzip -l $drupalZip  | head -4 | grep -c "/"`
ctx logger info "${currHostName}:$0 :Unzipping ${drupalZip} contentLevel is ${contentLevel}..."
if [ $contentLevel -eq 0 ] ; then
	cd $documentRoot
	rm -rf index.php
	unzip -o $zipLocation/$drupalZip
else
	unzip -o $drupalZip
	rm -f $drupalZip
	echo "mv unzipped folder to appFolder"
	ls | xargs -I file mv file appFolder
	cd appFolder
	echo "Copying application files to ${documentRoot}/ ..."
	ls | xargs -I file sudo cp -r file $documentRoot/  
fi
					
popd
rm -rf /tmp/tmpZipFolder

sitesFolder="${documentRoot}/sites"
drupalDefaultFolder="${sitesFolder}/default"

drupalDefaultSettingsFilePath="${drupalDefaultFolder}/default.settings.php"
drupalSettingsFilePath="${drupalDefaultFolder}/settings.php"

ctx logger info "${currHostName}:$0 :Chmodding a+w ${drupalDefaultFolder} ..."
sudo chmod -R 777 $sitesFolder

ctx logger info "${currHostName}:$0 :Copying ${drupalDefaultSettingsFilePath} to ${drupalSettingsFilePath} ..."
sudo cp -f $drupalDefaultSettingsFilePath $drupalSettingsFilePath

ctx logger info "${currHostName}:$0 :Chmodding a+w ${drupalSettingsFilePath} ..."
sudo chmod 777 $drupalSettingsFilePath
		
ctx logger info "${currHostName}:$0 :Setting db for Drupal ${drupalVersion} ..."
origDbConnString="\$databases = array()"
newMySqlConnString="\$databases = array();\n"
newMySqlConnString="${newMySqlConnString} \n\$databases['default']['default'] = array("
newMySqlConnString="${newMySqlConnString} \n      'driver' => 'mysql',"
newMySqlConnString="${newMySqlConnString} \n      'database' => '${databaseName}',"
newMySqlConnString="${newMySqlConnString} \n      'username' => '${dbUsername}',"
newMySqlConnString="${newMySqlConnString} \n      'password' => '${dbPassword}',"
newMySqlConnString="${newMySqlConnString} \n      'port' => ${dbPort},"
newMySqlConnString="${newMySqlConnString} \n      'host' => '${dbHost}',"
newMySqlConnString="${newMySqlConnString} \n      'prefix' => '',"
newMySqlConnString="${newMySqlConnString} \n)"
sudo sed -i -e "s%$origDbConnString%$newMySqlConnString%g" ${drupalSettingsFilePath} || error_exit $? "Failed on: sudo sed -i -e s/\$origDbConnString ... in ${drupalSettingsFilePath}"

echo "\$conf['error_level'] = 2;" >> $drupalSettingsFilePath
echo "ini_set('display_errors', 1);" >> $drupalSettingsFilePath


sitesAll=${sitesFolder}/all
modules=$sitesAll/modules
themes=$sitesAll/themes
libraries=$sitesAll/libraries
 
ctx logger info "${currHostName}:$0 :Creating ${modules} ...
sudo mkdir -p $modules

ctx logger info "${currHostName}:$0 :Creating ${themes} ...
sudo mkdir -p $themes

ctx logger info "${currHostName}:$0 :Creating ${libraries} ...
sudo mkdir -p $libraries
	
ctx logger info "${currHostName}:$0 :Chmodding +w ${modules} ...	
sudo chmod a+w $modules

ctx logger info "${currHostName}:$0 :Chmodding +w ${themes} ...	
sudo chmod a+w $themes

ctx logger info "${currHostName}:$0 :Chmodding +w ${libraries} ...	
sudo chmod a+w $libraries
				
ctx logger info "${currHostName}:$0 :End of ${currHostName}:$0"

ctx logger info "${currHostName}:$0 Installing Drush..."
sudo apt-get install -y -q drush
