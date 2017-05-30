#!/bin/bash
#
#Preinstallation: jq
#ex: sh downloadFromYoutube.sh --token YOUTUBE_TOKEN --list SONG_LIST.txt
#		list -> default is "list.txt"

MAC=MACOS
WIN=WIN
LINUX=LINUX

function getOS() {
	OS=$(uname -s)
	if [[ $OS =~ "Darwin" ]]; then
		echo $MAC
	elif [[ $OS =~ "CYGWIN" ]] ; then
		echo $WIN
	elif [[ $OS =~ "Linux" ]]; then
		echo $LINUX
	fi
}

function getFileSpace() {
	if [ $1 == "$MAC" ]; then
		echo $(<"$2" wc -c  || echo $?)
	else
		echo $(stat --printf="%s" "$2" || echo $?)
	fi
}

OS=$(getOS)
LISTFILE="list.txt"

# command paraments
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -t|--token)
    TOKEN="$2"
    shift
    ;;
    -l|--list)
    LISTFILE="$2"
    shift
    ;;
    --default)
    DEFAULT=YES
    ;;
    *)
    ;;
esac
shift
done

# check token
if [[ -z "$TOKEN" ]]; then
	echo Token is necessary!
	exit
fi

echo Youtube API Token: $TOKEN

# Get songs from list file
while read name; do
	# check if song is exist
	SONG=$(echo ${name##*-})
	ISEXIST=$(ls -A1 | grep "${SONG}")
	if [[ -z "$name" ]]; then
		continue
	elif [[ "${ISEXIST}" ]]; then
		ISEXIST=$(getFileSpace $OS "$ISEXIST")
		if [[ "${ISEXIST}" -gt 1000000 ]]; then
			printf "$name is Existed\n"
			continue
		fi
	fi

	# get first of result from youtube search
	URL='https://www.googleapis.com/youtube/v3/search'
	if [ "$OS" == "$WIN" ]; then
		URL=$(echo $URL | dos2unix)
	fi
	printf "$URL\n"
	RESULT=$(curl -G "$URL" \
	--data-urlencode "part=snippet" \
	--data-urlencode "key=$TOKEN" \
	--data-urlencode "q=$name" )

	ID=$(echo $RESULT | jq -r '.items[0]["id"]["videoId"]')
	TITLE=$(echo $RESULT | jq -r '.items [0]["snippet"]["title"]' | xargs)
	TYPE=".mp3"

	FILENAME=$TITLE$TYPE
	if [ "$OS" == "$WIN" ]; then
		FILENAME=$(echo $FILENAME | dos2unix)
	fi
	printf "$FILENAME\n"

	# URL about converting youtube video to mp3(music) 
	URL=http://www.youtubeinmp3.com/fetch/?video=https://www.youtube.com/watch?v=$ID
	if [ "$OS" == "$WIN" ]; then
		URL=$(echo $URL | dos2unix)
	fi

	SPACE=$(getFileSpace $OS "$FILENAME")
	printf "SPACE: $SPACE\n"

	# Download mp3, it will retry with delay if fail
	DELAY=2
	while [ $SPACE -lt 1000000 ]
	do
		printf "$FILENAME is Downloading!\n"
		sleep $DELAY

		echo curl -L -o "$FILENAME" $URL
		curl -L -o "$FILENAME" $URL

		SPACE=$(getFileSpace $OS "$FILENAME")
		printf "SPACE: $SPACE\n"

		let 'DELAY=DELAY * 2'
		if [ $DELAY -gt 256 ]; then
			printf "$FILENAME is Fail!\n"
			break
		elif [ "${SPACE}" -gt 1000000 ]; then
			printf "$FILENAME is Success!\n"
		else
			printf "$FILENAME will retry by DELAY: $DELAY \n"
		fi
	done
done <$LISTFILE




