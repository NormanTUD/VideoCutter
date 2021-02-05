#!/bin/bash


INSTALL=0
threshold=80
DIR=

for i in "$@"; do
	case $i in
	    --threshold=*)
	    threshold="${i#*=}"
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
	sudo apt-get install python
	sudo pip install imagehash
	sudo apt-get install imagemagick findimagedupes ffmpeg
fi

CUTIMAGE="$DIR/cutimage.jpg" 

function get_framerate {
	echo $(mediainfo $1 | egrep "Frame rate *:" | head -n1 | sed -e 's/.*: //' | sed -e 's/\..* FPS//')
}

function get_img_difference {
	img1=$1
	img2=$2
	#perl imgdiff.pl $img1 $img2
	echo $(python hashes.py $img1 $img2)
}

function img_diff_close_enough {
	img1=$1
	img2=$2
	img_diff=$(get_img_difference $img1 $img2)

	if (( $(echo "$img_diff > $threshold" |bc -l) )); then
		return 0
	else
		return 1
	fi
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
		fi

		if img_diff_close_enough $compareimg $thisfile; then
			frameid=$(echo $thisfile | sed -e 's/.*\///' | sed -e 's/\.jpg$//')
			break
		fi
	done
	
	CUTTIMESECONDS=$(echo "($frameid*10)/$FRAMERATE" | bc)

	echo $CUTTIMESECONDS
}

function docut {
	file=$1

	#backupfilename=$file
	#i=0
	#while [[ -e $backupfilename ]]; do
	#	i=$(($i + 1))
	#	backupfilename=$file.$i
	#done
	#cp $file $backupfilename

	tmpdir=tmp/$(md5sum $file | sed -e 's/ .*//')/
	mkdir -p $tmpdir

	if [[ ! -e "$tmpdir/00000001.jpg" ]]; then
		ffmpeg -i $file -vf "select=not(mod(n\,10))" -vsync vfr $tmpdir/%08d.jpg
	fi

	CUTTIME=$(find_cut $file $tmpdir)

	ffmpeg -ss $CUTTIME  -i $file -vcodec copy -acodec copy $(dirname $file)/nointro_$(basename $file)
}

if [[ -d $DIR ]]; then
	if [[ -e $CUTIMAGE ]]; then
		ls $DIR/*.mp4
		for filename in $DIR/*.mp4; do
			if [[ ! -e $(dirname $file)/nointro_$(basename $file) ]]; then
				docut $filename
			else
				echo "$(dirname $file)/nointro_$(basename $file) already exists"
			fi
		done
	else
		echo "$CUTIMAGE not found"
	fi
else
	echo "$DIR not found"
fi
