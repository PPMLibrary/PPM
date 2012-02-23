#!/usr/bin/env bash

################################################################################
# Three use cases:
#       clients
#       ppm                    --ppm
#       ppmnumerics            --ppmnumerics
################################################################################

PPM=0
NUM=0

#extended regexp flag
ef=$(echo 'aaa' | $SED -E 's/a+/b/')

if [[ $ef == b ]]
then
    ef="-E"
else
    ef="-r"
fi

if [[ $1 == --ppm ]]
then
    PPM=1
    shift
    # append slash if not present
    if [ `expr $SRCDIR : '.*/$'` -eq 0 ]; then SRCDIR="${SRCDIR}/"; fi
elif [[ $1 == --ppmnumerics ]]
then
    NUM=1
    shift
else
    SRCDIR=""
fi

# append slash if not present
if [ `expr $OBJDIR : '.*/$'` -eq 0 ]; then OBJDIR="${OBJDIR}/"; fi

fullname=$1
outfile=$2

# get the dir part of the name
fulldir=`expr "$fullname" : '\(.*/\)'`

# strip srcdir from dir
dir=${fulldir#$SRCDIR}
if [ -n "$dir" ]; then if [ `expr $dir : '.*/$'` -eq 0 ]; then dir="${dir}/"; fi; fi

fname=${1##*/}
ppfile=${OBJDIR}${dir}$fname

# echo "# generating dependency makefile for $1"
# echo "#"
# echo "# paths"
# echo "#"
# echo "# fulldir: $fulldir"
# echo "#     dir: $dir"
# echo "#   fname: $fname"
# echo "#  ppfile: $ppfile"

# use cpp to get the #include deps
preproc=$($CPP $INC $DEFINE -w -MM ${SRCDIR}${dir}$fname \
        | $SED $ef "s/^\s+/\t/
                    s|([a-z0-9_]+)\.o|${OBJDIR}${dir}\1.f|I")

# resolve fortran include deps
finclude=$(grep -E -i "^[ \t]*include " $ppfile \
         | $SED $ef -e 's/^\s*//' \
                    -e '/mpif.*\.h/d' \
                    -e "s|include\s*|\t|I" \
                    -e 's/"//g' \
                    -e "s/'//g" \
                    -e '$q;s/$$/ \\/g')
if [ "$finclude" ]
then
    finclude="${OBJDIR}${1/\.f/.o}: ${finclude:1}"
else
    finclude=""
fi

# resolve use statement deps
fuse=$(grep -E -i "^[ \t]*use " $ppfile \
     | $SED $ef 's/^\s*//
                 s/,.*//
                 s/use[ \t]*//I')

fuse=`echo "$fuse" | sort | uniq`

# filter stuff that is in the global include dirs
filtered=''

INC="${INC//-I/}"
REGEX=".*_.*"

for dep in $fuse
do
    exists=0
    for dir in $INC
    do
	if [ -e "$dir/$dep.mod" ]
	then
	    exists=1
	fi
    done
    if [ ! $exists -eq 1 ]
    then
	# check if prefix is a dir name
	suffix=$dep
	prefix=${suffix%%_*}
	while [[ $suffix =~ $REGEX ]]
	do
	    suffix=${suffix#*_}
	    if [ ! -d $prefix ]; then break; fi
	    dep="${prefix}/${suffix}"
	    prefix="$prefix/${suffix%%_*}"
	done
	filtered="$filtered
$dep"
    fi
done

filtered=${filtered:1}

if [ "$filtered" ];
then
    fuse=$(echo "$filtered" \
	 | $SED $ef -e 's/$$/.o/' \
                    -e "s|^|\t${OBJDIR}|" \
                    -e '$q;s/$$/ \\/g')
    fuse="${ppfile/\.f/.o}: ${fuse:1}"
else
    fuse=''
fi

# print

if [ -z $outfile ]
then
    echo -e "\n# FILE AUTOGENERATED BY deps.sh\n"
    if [ "$preproc"  ]; then echo -e "# CPP\n${preproc}";  fi
    if [ "$finclude" ]; then echo -e "# INC\n${finclude}"; fi
    if [ "$fuse"     ]; then echo -e "# USE\n${fuse}";     fi
else
    echo -e "\n# FILE AUTOGENERATED BY deps.sh\n"             > $outfile
    if [ "$preproc"  ]; then echo -e "# CPP\n${preproc}"      > $outfile; fi
    if [ "$finclude" ]; then echo -e "# INC\n${finclude}"     > $outfile; fi
    if [ "$fuse"     ]; then echo -e "# USE\n${fuse}"         > $outfile; fi
fi
