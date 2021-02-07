#!/bin/bash

echoerr() {
	echo "$@" 1>&2
}

function red_text {
	echoerr -e "\e[31m$1\e[0m"
}

function green_text {
	echoerr -e "\e[92m$1\e[0m"
}

function debug_code {
	echoerr -e "\e[93m$1\e[0m"
}

function sec2time () {
	date -u -d "0+$1sec" +%T.%3N
}

install=0
threshold=90
minintrotimesearch=0
maxintrotimesearch=300
nthframe=30
dir=
algorithm=findimagedupes
secondsback=0

function show_help {
	echo "This script cuts intros from video files on a folder on the basis of a frame you have to provide which signifies where the intro ends.
Save this frame in the folder given to --dir as "cutimage.jpg". Frames by all *.mp4-files will be checked for similiarity to that frame.
The first one that's --threshold in color* will be the frame where the video will be cut.

*threshold right now only determined by vector distance to the zero position (all black) of the whole image as an average color.

--threshold=$threshold					Threshold of similiarity between the cutimage and a frame from the video to be cut
--minintrotimesearch=$minintrotimesearch		Minimal number of seconds to search
--maxintrotimesearch=$maxintrotimesearch		The maximum number of seconds in the video where a cut is expected to be
--nthframe=$nthframe					The script only looks at every nthframe to determine the cut (saves a lot of time, but may lead to skipping
							an intro; if no intro is found with --nthframe, it will take every frame by default)
--dir=folder						The folder where the mp4 files and the cutimage.jpg must lie
--install						Installs the neccessary dependencies
--debug							Enables set -ex
--help							This help
--algorithm=1x1avgcolor,hamming,			Which algorithm to use
            findimagedupes
--secondsback=0						Number of seconds to go back before cutting"
}

for i in "$@"; do
	case $i in
		--threshold=*)
			threshold="${i#*=}"
			;;

		--secondsback=*)
			secondsback="${i#*=}"
			;;


		--minintrotimesearch=*)
			minintrotimesearch="${i#*=}"
			;;

		--maxintrotimesearch=*)
			maxintrotimesearch="${i#*=}"
			;;

		--algorithm=*)
			algorithm="${i#*=}"
			;;

		--nthframe=*)
			nthframe="${i#*=}"
			;;

		--dir=*)
			dir="${i#*=}"
			;;

		--install)
			install=1
			;;

		--debug)
			set -ex
			;;

		--help)
			show_help
			exit
			;;

		*)
			red_text "Unknown option $i"
			show_help
			exit
			;;
	esac
done


if [[ ! ( $algorithm == "hamming" || $algorithm == "1x1avgcolor" || $algorithm == "findimagedupes" ) ]]; then
	echoerr "Algorithm name $algorithm not found"
	exit 1
fi

if [[ "$install " == "1" ]]; then
	sudo apt-get install python ffmpeg perl imagemagick findimagedupes bc
	sudo pip install imagehash
fi


function get_framerate {
	echo $(mediainfo "$1" | egrep "Frame rate *:" | head -n1 | sed -e 's/.*: //' | sed -e 's/\..* FPS//')
}

function find_cut {
	CUTIMAGE=$1
	file=$2
	tmpdir=$3
	thisnthframe=$4

	FRAMERATE=$(get_framerate "$file")

	frameid=""
	compareimg=""
	for thisfile in $tmpdir/*.jpg; do
		if [[ -z $compareimg ]]; then
			toresizewidth=$(identify -format '%wx%h' "$thisfile")
			compareimg=$dir/cutimage_${toresizewidth}.jpg
			if [[ ! -e $compareimg ]]; then
				convert $CUTIMAGE -resize $toresizewidth $compareimg
			fi
			break
		fi
	done

	if [[ $algorithm == "hamming" ]]; then
		frameid=$(python get_similiar_frame.py $threshold $compareimg $tmpdir)
	elif [[ $algorithm == "1x1avgcolor" ]]; then
		frameid=$(perl compare_images.pl $threshold $compareimg $tmpdir)
	elif [[ $algorithm == "findimagedupes" ]]; then
		cp $CUTIMAGE $tmpdir/cutimage.jpg
		frameid=$(for i in $(find $tmpdir \( -name '*.jpg' -o -name '*.png' \) -print0 | findimagedupes -0 - | grep cutimage); do echo $(basename $i); done | egrep -v "^\s*$" | grep -v "cutimage.jpg" | sort -n | sed -e 's/\.jpg//' | head -n1)
		rm $tmpdir/cutimage.jpg
	else
		echoerr "Algorithm name $algorithm not found"
		exit 1
	fi
	
	if [[ ! -z $frameid ]]; then
		CUTTIMESECONDS=$(echo "($frameid*$thisnthframe)/$FRAMERATE" | bc)
		CUTTIMESECONDS=$(echo "$CUTTIMESECONDS-$minintrotimesearch-$secondsback" | bc)

		echo $CUTTIMESECONDS
	else
		echo "NOTIMEFOUND"
	fi
}

function docut {
	CUTIMAGE=$1
	file=$2
	thisnthframe=$3
	if [[ -z $thisnthframe ]]; then
		thisnthframe=$nthframe
	fi

	tmpdir=tmp/$(md5sum "$file" | sed -e 's/ .*//')_${thisnthframe}/
	mkdir -p $tmpdir

	if [[ ! -e "$tmpdir/00000001.jpg" ]]; then
		ffmpeg -i "$file" -vf "select=not(mod(n\,$thisnthframe))" -ss $(sec2time $minintrotimesearch) -to $maxintrotimesearch -vsync vfr $tmpdir/%08d.jpg
	fi

	CUTTIME=$(find_cut "$CUTIMAGE" "$file" "$tmpdir" "$thisnthframe")

	if [[ "$CUTTIME" == "NOTIMEFOUND" ]]; then
		if [[ $thisnthframe == 1 ]]; then
			red_text "No cut time found for $file"
			echo "$file" >> $dir/missing_files
		else
			red_text "No cut time found for $file, trying again with 3-frame-granularity"
			docut "$CUTIMAGE" "$file" 3
		fi
	else
		toname=$(dirname "$file")/nointro_$(basename "$file")
		ffmpeg -ss $CUTTIME  -i "$file" -vcodec copy -acodec copy "$toname"
		green_text "OK: $file was cut from $CUTTIME on and saved to $toname"
	fi
}

if [[ -d $dir ]]; then
	CUTIMAGE="$dir/cutimage.jpg" 
	if [[ -e $CUTIMAGE ]]; then
		IFS=$'\n'; for filename in $(ls $dir/*.mp4); do
			if [[ "$filename" =~ .*nointro.* ]]; then
				green_text "Not doing files that already are nointro"
			else
				if [[ ! -e $(dirname "$filename")/nointro_$(basename "$filename") ]]; then
					docut "$CUTIMAGE" "$filename"
				else
					green_text "$(dirname "$filename")/nointro_$(basename "$filename") already exists"
				fi
			fi
		done
	else
		red_text "$CUTIMAGE not found"
	fi
else
	red_text "$dir not found"
fi

green_text "Done. Took $SECONDS seconds."
