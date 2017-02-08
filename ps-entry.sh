#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	CMDARG="$@"
fi

# Get config
DATADIR="$("mysqld" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
if [ ! -e "$DATADIR/init.ok" ]; then
	cd /restore
	mkdir -p "$DATADIR"
	if [ ! -f /usr/local/bin/qpress ];
	then
		echo "Installing qpress! "
		wget -q "http://www.quicklz.com/qpress-11-linux-x64.tar" -O- | tar -xf - -C /tmp/
		if [ ! $? -eq 0 ];
		then
			echo "Failed decompressing qpress"
			exit 1
		fi
		mv /tmp/qpress /usr/local/bin/qpress
	fi
	
	# Decrypt all the files
	echo -n "Decrypting all files using the encryption key (This can take a while): "
	innobackupex --use-memory=4G --parallel=4 --decrypt=AES128 --encrypt-key-file=/restore/.backupencryptionkey ${PWD}/full >> backup.log 2>&1
	if [ -d "incr" ];
	then
		find ${PWD}/incr/* -maxdepth 0 -type d -exec innobackupex --use-memory=4G --parallel=4 --decrypt=AES128 --encrypt-key-file=/restore/.backupencryptionkey {} >> backup.log 2>&1 \;
	fi
	echo " Done"
	echo -n "Remove encrypted files after decryption: "
	find . -name "*.xbcrypt" -exec rm {} \;
	echo "Done"
	# Decompress all directorys
	echo -n "Decompressing full backup (This can take a while): "
	innobackupex --use-memory=4G --parallel=4 --decompress ${PWD}/full >> backup.log 2>&1
	echo "Done"
	# Remove compressed files after extraction
	find ${PWD}/full -name "*.qp" -exec rm {} \;
	
	# Prepare full backup and apply incrementals if any
	if [ -d "incr" ];
	then
		echo -n "Preparing full log for incrementals: "
		innobackupex --use-memory=4G --parallel=4 --redo-only --apply-log ${PWD}/full >> backup.log 2>&1
		echo "Done"
		echo "Applying incrementals to full backup: "
		declare -a files
		files=($(find ${PWD}/incr/* -maxdepth 0 -type d -regextype posix-extended -regex '^.*[0-9]{4}$'|sort))
		for DIR in "${files[@]}";
		do
					echo -n "Processing ${DIR}: "
				innobackupex --use-memory=4G --parallel=4 --decompress ${DIR} >> backup.log 2>&1
				find ${DIR} -name "*.qp" -exec rm {} \;
				innobackupex --use-memory=4G --parallel=4 --apply-log --redo-only --incremental-dir=${DIR} ${PWD}/full >> backup.log 2>&1
				rm -rf "${DIR}"
				echo "Done"
		done
		echo "Done"
		rm -rf incr
	fi
	# Apply logs to backup
	echo -n "Apply log with incrementals to full backup: "
	innobackupex --use-memory=4G --parallel=4 --apply-log ${PWD}/full >> backup.log 2>&1
	echo " Done"

innobackupex --move-back ./full
fi

touch $DATADIR/init.ok
chown -R mysql:mysql "$DATADIR"

exec mysqld --user=mysql --log-error=${DATADIR}error.log $CMDARG