#!/bin/bash
# DONT BE A KNOB. CONSULT THE FFMPEG DOCUMENTATION IF NEEDED.
desired_audio_codec=aac
desired_video_codec=h264
desired_video_profile=High
desired_video_level=4.1
desired_video_level_integer=41
desired_video_width=1280
desired_output_path=/storage/plex/temp

RESET="\e[0m"
RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
BLUE="\e[94m"
PINK="\e[95m"
CYAN="\e[96m"
WHITE="\e[97m"

file1=`basename "$1"`
file2=${file1%.*}
FFMPEG_OPTS="-map_metadata -1"

declare -a AUDIOCODECS
declare -a AUDIOLANG
declare -a VIDEOCODECS
declare -a VIDEOLEVELS
declare -a VIDEOPROFILES
declare -a VIDEORESOLUTIONS

audio_streams=`ffprobe "$file1" -v error -select_streams a -show_entries stream=index -of default=noprint_wrappers=1:nokey=1 | wc -l`
video_streams=`ffprobe "$file1" -v error -select_streams v -show_entries stream=index -of default=noprint_wrappers=1:nokey=1 | wc -l`
echo -e $YELLOW"File:             "$RESET$file1

# loop through audio stream(s) and parse codec/language
stream=0
while [ $stream -lt $audio_streams ]
do
    AUDIOCODECS[$stream]=`ffprobe -v error -select_streams a:"$stream" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file1"`
	AUDIOLANG[$stream]=`ffprobe -v error -show_entries stream_tags=language -select_streams a:"$stream" -of default=noprint_wrappers=1:nokey=1 "$file1"`

    if [ ${AUDIOCODECS[$stream]} = $desired_audio_codec ]; then
        STATUS=$GREEN
        FFMPEG_OPTS="$FFMPEG_OPTS -c:a:$stream copy"
    else
        STATUS=$RED
        FFMPEG_OPTS="$FFMPEG_OPTS -c:a:$stream $desired_audio_codec"
    fi

    if [ "${AUDIOLANG[$stream]}" = "" ] || [ "${AUDIOLANG[$stream]}" = "und" ]; then
        echo -e $RED"Error: "$RESET"           Audio stream "$stream" has an unset language. Please specify the 3-digit language code:"$RESET
        read lang
        AUDIOLANG[$stream]="$lang"
        FFMPEG_OPTS="$FFMPEG_OPTS -metadata:s:a:$stream language=${AUDIOLANG[$stream]}"
    fi
    
    echo -e $YELLOW"Audio stream:     "$RESET$stream", Codec: "$STATUS${AUDIOCODECS[$stream]}$RESET", Language: "${AUDIOLANG[$stream]}
    ((stream++))
done

stream=0
while [ $stream -lt $video_streams ]
do
    VIDEOCODECS[$stream]=`ffprobe -v error -select_streams v:"$stream" -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file1"`
    VIDEOLEVELS[$stream]=`ffprobe -v error -select_streams v:"$stream" -show_entries stream=level -of default=noprint_wrappers=1:nokey=1 "$file1"`
    
    if [ ${VIDEOLEVELS[$stream]} -eq 6 ]; then
	    VIDEOLEVELS[$stream]=60
    elif [ ${VIDEOLEVELS[$stream]} -eq 5 ]; then
	    VIDEOLEVELS[$stream]=50
    elif [ ${VIDEOLEVELS[$stream]} -eq 4 ]; then
	    VIDEOLEVELS[$stream]=40
    elif [ ${VIDEOLEVELS[$stream]} -eq 3 ]; then
	    VIDEOLEVELS[$stream]=30
    elif [ ${VIDEOLEVELS[$stream]} -eq 2 ]; then
	    VIDEOLEVELS[$stream]=20
    elif [ ${VIDEOLEVELS[$stream]} -eq 1 ]; then
	    VIDEOLEVELS[$stream]=10
    fi
    
    VIDEOPROFILES[$stream]=`ffprobe -v error -select_streams v:"$stream" -show_entries stream=profile -of default=noprint_wrappers=1:nokey=1 "$file1"`
    VIDEORESOLUTIONS[$stream]=`ffprobe -v error -select_streams v:"$stream" -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$file1"`
    
    if [ ${VIDEOCODECS[$stream]} = $desired_video_codec ]; then
        CODECSTATUS=$GREEN
        FFMPEG_OPTS="$FFMPEG_OPTS -c:v:$stream copy"
    else
        CODECSTATUS=$RED
        FFMPEG_OPTS="$FFMPEG_OPTS -c:v:$stream $desired_video_codec"
    fi

    if [ ${VIDEOLEVELS[$stream]} -le $desired_video_level_integer ]; then
        LEVELSTATUS=$GREEN
    else
        LEVELSTATUS=$RED
        FFMPEG_OPTS="$FFMPEG_OPTS -level:v:$stream $desired_video_level"
    fi

    if [ "${VIDEOPROFILES[$stream]}" = "$desired_video_profile" ]; then
        PROFILESTATUS=$GREEN
    else
        PROFILESTATUS=$RED
        FFMPEG_OPTS="$FFMPEG_OPTS -profile:v:$stream $desired_video_profile"
    fi

    if [ ${VIDEORESOLUTIONS[$stream]} -le $desired_video_width ]; then
        RESOLUTIONSTATUS=$GREEN
    else
        RESOLUTIONSTATUS=$RED
        FFMPEG_OPTS=$FFMPEG_OPTS -vf scale="$desired_video_width:-1"
    fi
    
    echo -e $YELLOW"Video stream:     "$RESET$stream", Codec: "$CODECSTATUS${VIDEOCODECS[$stream]}$RESET", Level: "$LEVELSTATUS${VIDEOLEVELS[$stream]}$RESET", Profile: "$PROFILESTATUS${VIDEOPROFILES[$stream]}$RESET", Width: "$RESOLUTIONSTATUS${VIDEORESOLUTIONS[$stream]}$RESET
    ((stream++))
done

# ensure MOOV atom is at start of file for fast streaming
FFMPEG_OPTS="$FFMPEG_OPTS -movflags faststart"

echo -e $YELLOW"Encoder options:  "$RESET$FFMPEG_OPTS
echo ""
ffmpeg -loglevel quiet -stats -hide_banner -i "$file1" $FFMPEG_OPTS $desired_output_path/"$file2".mp4