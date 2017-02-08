Start with copying the desired backup to your computer

then echo the backup key into the folder where inc and full is like so:

echo -n 'encryptionkey' > .backupencryptionkey

start local server with:

docker run -d -v /path/to/backupfolder:/restore -p 3306:3306 pasientskyhosting/docker-mysqlrestore