#!/bin/bash

#set -e

install=0
threshold=90
maxintrotimesearch=300
nthframe=30
dir=

for i in "$@"; do
	case $i in
	    --threshold=*)
		    threshold="${i#*=}"
	    ;;

	    --maxintrotimesearch=*)
		    maxintrotimesearch="${i#*=}"
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
		    set -x
	    ;;

	    *)
		    # unknown option
	    ;;
	esac
done

if [[ "$install " == "1" ]]; then
	sudo apt-get install python ffmpeg perl imagemagick
	sudo pip install imagehash
fi


function get_framerate {
	echo $(mediainfo "$1" | egrep "Frame rate *:" | head -n1 | sed -e 's/.*: //' | sed -e 's/\..* FPS//')
}

function find_cut {
	CUTIMAGE=$1
	file=$2
	tmpdir=$3

	FRAMERATE=$(get_framerate "$file")

	frameid=0
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

	#frameid=$(python get_similiar_frame.py $threshold $compareimg $tmpdir)
	frameid=$(perl compare_images.pl $threshold $compareimg $tmpdir)
	
	if [[ ! -z $frameid ]]; then
		CUTTIMESECONDS=$(echo "($frameid*$nthframe)/$FRAMERATE" | bc)

		echo $CUTTIMESECONDS
	else
		echo "NOTIMEFOUND"
	fi
}

function docut {
	CUTIMAGE=$1
	file=$2

	tmpdir=tmp/$(md5sum "$file" | sed -e 's/ .*//')/
	mkdir -p $tmpdir

	if [[ ! -e "$tmpdir/00000001.jpg" ]]; then
		ffmpeg -i "$file" -vf "select=not(mod(n\,$nthframe))" -to $maxintrotimesearch -vsync vfr $tmpdir/%08d.jpg
	fi

	CUTTIME=$(find_cut "$CUTIMAGE" "$file" "$tmpdir")

	if [[ "$CUTTIME" == "NOTIMEFOUND" ]]; then
		echo "No cut time found for $file"
	else
		toname=$(dirname "$file")/nointro_$(basename "$file")
		ffmpeg -ss $CUTTIME  -i "$file" -vcodec copy -acodec copy "$toname"
	fi
}

if [[ -d $dir ]]; then
	CUTIMAGE="$dir/cutimage.jpg" 
	if [[ -e $CUTIMAGE ]]; then
		IFS=$'\n'; for filename in $(ls $dir/*.mp4); do
			if [[ "$filename" =~ .*nointro.* ]]; then
				echo "Not doing files that already are nointro"
			else
				if [[ ! -e $(dirname "$filename")/nointro_$(basename "$filename") ]]; then
					docut "$CUTIMAGE" "$filename"
				else
					echo "$(dirname "$filename")/nointro_$(basename "$filename") already exists"
				fi
			fi
		done
	else
		echo "$CUTIMAGE not found"
	fi
else
	echo "$dir not found"
fi
