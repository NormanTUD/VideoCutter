#!/bin/bash


INSTALL=0
threshold=90
maxintrotimesearch=300
nthframe=20
DIR=

for i in "$@"; do
	case $i in
	    --threshold=*)
	    threshold="${i#*=}"
	    ;;

	    --maxintrotimesearch=*)
	    maxintrotimesearch="${i#*=}"
	    ;;

	    --dir=*)
	    DIR="${i#*=}"
	    ;;

	    --install)
		    INSTALL=1
	    ;;

	    --debug)
		    set -x
	    ;;

	    *)
		    # unknown option
	    ;;
	esac
done

if [[ "$INSTALL" == "1" ]]; then
	sudo apt-get install python ffmpeg
	sudo pip install imagehash
fi

CUTIMAGE="$DIR/cutimage.jpg" 

function get_framerate {
	echo $(mediainfo $1 | egrep "Frame rate *:" | head -n1 | sed -e 's/.*: //' | sed -e 's/\..* FPS//')
}

function find_cut {
	file=$1
	tmpdir=$2

	FRAMERATE=$(get_framerate $file)

	frameid=0
	compareimg=""
	for thisfile in $tmpdir/*.jpg; do
		if [[ -z $compareimg ]]; then
			toresizewidth=$(identify -format '%wx%h' $thisfile)
			compareimg=$DIR/cutimage_${toresizewidth}.jpg
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
	file=$1

	tmpdir=tmp/$(md5sum $file | sed -e 's/ .*//')/
	mkdir -p $tmpdir

	if [[ ! -e "$tmpdir/00000001.jpg" ]]; then
		ffmpeg -i $file -vf "select=not(mod(n\,$nthframe))" -to $maxintrotimesearch -vsync vfr $tmpdir/%08d.jpg
	fi

	CUTTIME=$(find_cut $file $tmpdir)

	if [[ "$CUTTIME" == "NOTIMEFOUND" ]]; then
		echo "No cut time found for $file"
		sleep 5
	else
		ffmpeg -ss $CUTTIME  -i $file -vcodec copy -acodec copy $(dirname $file)/nointro_$(basename $file)
	fi
}

if [[ -d $DIR ]]; then
	if [[ -e $CUTIMAGE ]]; then
		ls $DIR/*.mp4
		for filename in $DIR/*.mp4; do
			if [[ ! -e $(dirname $filename)/nointro_$(basename $filename) ]]; then
				docut $filename
			else
				echo "$(dirname $filename)/nointro_$(basename $filename) already exists"
			fi
		done
	else
		echo "$CUTIMAGE not found"
	fi
else
	echo "$DIR not found"
fi
