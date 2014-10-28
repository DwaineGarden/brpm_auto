#############################################################################
# Copyright @ 2012-2014 BMC Software, Inc.                                  #
# This script is supplied as a template for performing the defined actions  #
# via the BMC Release Package and Deployment. This script is written        #
# to perform in most environments but may require changes to work correctly #
# in your specific environment.                                             #
#############################################################################
#
# Set config files for Apache
#

#
# set the home dir for apache
#
if [ -z "$HTTPD_HOME" ]
then
	HTTPD_HOME="/etc/httpd"
fi


if [ -z "$VL_INPUT_DATA" ]; then
	echo "This script should be executed within the context of a BRPD transaction." 1>&2
 	exit 1
fi


#
# Parse configurations sent through VL_INPUT_DATA
#
error=0
while read line
do
	echo $line | grep -i '\[Apache_2]' > /dev/null
	if [ $? -eq 0 ];then
		apachePath=$(expr match "$line" '\[[^[]*\]\[\([^[]*\)\]')
		apachePath="${HTTPD_HOME}/${apachePath}"
		if [ ! -f "$apachePath" ]; then
			echo "$apachePath not a valid path to file" 1>&2
			exit 1
		fi
		theRest=$(expr match "$line" '\[[^[]*\]\[[^[]*\]\(.*\)')
		continue
	fi

	# If we got here, setting = line
	setting=$line

	# Define my reserved words
	triples="loadmodule addicon addlanguage addcharset alias addiconbytype addiconbyencoding sslrandomseed addtype"
	scopes="directory directorymatch files filesmatch location locationmatch virtualhost ifmodule"

	triple=
	scope=
	scopeCount=0

	# Parse "theRest" for triples and scope keywords
	if [ -n "$theRest" ];  then
		theRest=${theRest//[/}
		split=${theRest//]/,}

		# try to figure out what they are
		OLDIFS=$IFS
		IFS=,
		for object in $split
		do
			if [ -z "$object" ]; then
				continue
			fi
			first=`echo $object | cut -d" " -f1 | awk '{print tolower($0)}'`
			# is it a scope element or a triple?
			if [ ! "$triples" == "${triples/$first/}" ]; then
				triple=$object
			fi
			if [ ! "$scopes" == "${scopes/$first/}" ]; then
				if [ -z "$scope" ]; then
					scope=$object
				else
					scope="$scope,$object"
				fi
				scopeCount=$((scopeCount+1))
			fi
		IFS=$OLDIFS
		done
	fi

	#there aren't any = signs in an http.conf
	setting=${setting//=/ }

	token=`echo $setting | cut -d" " -f1`

	# if we triggered a triple, add it to settings
	if [ -n "$triple" ]; then
		setting="$triple $setting"
	fi

	# Now, go through the file line by line to find the correct element

	foundCount=
	foundScope=

	if [ -n "$scope" ]; then
		foundCount=0
		foundScope=0

	else
		foundScope=1
	fi

	TEMPFILE="vltmp_$$"
	updateComplete=0

	while IFS= read -r configLine
	do

		# find our line that we care about and use it to update the file
		if [ -n "$foundCount" -a "$foundScope" -eq "0" -a "$updateComplete" -eq "0" ]; then
			# have scope, must find it.
			type=`echo $scope | cut -d"," -f1`
			if [ -n "$type" ]; then
				typeRX=${type// /'\s'}
				typeRX=${typeRX//\"/\\\"}
				typeTest=$(expr "$configLine" : "\(^\s*<${typeRX}>\)")
				if [ -n "$typeTest" ]; then
					#found one!  increment foundCount
					foundCount=$((foundCount+1))
					scope=${scope/$type,/}
				fi
				if [ "$foundCount" -eq "$scopeCount" ]; then
					#found them all!
					foundScope=1
				fi
			fi
		fi
		if [ "$foundScope" -eq "1" -a "$updateComplete" -eq "0" ]; then
			# its for real now, find line and replace it.
			test1=$(expr "$configLine" : "\(^\s*${token}\)")
			test2=$(expr "$configLine" : "\(^\s*${triple}\s*${token}\)")
			if [ -n "$test1" -o -n "$test2" ]; then
				echo "************************************************************"
				echo "Updating $apachePath with setting $setting"
				echo "${setting}" >> $TEMPFILE
				foundScope=0
				updateComplete=1
				continue
			fi
		fi
		echo "${configLine}" >> $TEMPFILE

	done <$apachePath

	# write the file
	if [ "$updateComplete" -eq "1" ]; then
		cp -f $TEMPFILE $apachePath
	else
		echo "No updates applied for setting $setting" 1>&2
		error=$((error+1))
	fi
	rm -f $TEMPFILE

	echo "************************************************************"

done <$VL_INPUT_DATA

exit $error

