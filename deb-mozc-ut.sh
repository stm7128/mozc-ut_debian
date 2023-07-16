#!/bin/bash
set -e

# gen random dirname and makedir
dirname="/tmp/mozc-ut-"$(dd if=/dev/random bs=1 count=5 2> /dev/null| base64 | head -c 5)
mkdir $dirname
cd $dirname
pwd
del_tmpdir() {
	sudo rm -rf $dirname
}

if [ -z "$(grep -v "#deb-src" /etc/apt/sources.list|grep -v "#"|grep deb-src)" ]; then
	echo "deb-src repo is not enabled."
	del_tmpdir
	exit 1
fi

# check dep
installdep=""
if [ "$(which apt-src)" = "/usr/bin/apt-src" ]; then
	echo "apt-src found"
else
	echo "apt-src not found.\ninstalling."
	installdep+="apt-src "
fi


if [ "$(which git)" = "/usr/bin/git" ]; then
	echo "git found"
else
	echo -e "git not found. \ninstalling."
	installdep+="git "
fi


if [ "$(which ruby)" = "/usr/bin/ruby" ]; then
	echo "ruby found"
else
	echo -e "ruby not found. \ninstalling."
	installdep+="ruby"
fi

# instal dep
#
if [ "$installdep" ]; then
	echo "install dep."
	sudo apt install $installdep -y -qq
fi

# Determining the input method
echo -e "input method\n・ibus\n・fcitx\n・fcitx5\n・uim\n・emacs"
read -p "select input method: " inpmethod
read -p "The input method you have chosen is "$inpmethod". Please type "y" if you prefer: " oyn
if [ "$oyn" = y ]; then
	:
else
	del_tmpdir
	exit 0
fi
echo -e "Build Only:1\nBuild&install:2"
read -p "please type number: " build
# build dic
echo "build mozc-ut dic" 
git clone https://github.com/utuhiro78/merge-ut-dictionaries.git utdic
cd utdic/src
chmod +x ./make.sh
./make.sh

# download mozc source
echo "download mozc source"
cd $dirname
sudo apt-src update
apt-src install mozc
mozcsrcdir=$dirname"/"$(ls -d *mozc*/|sed -e s@/@@)"/"

mozc_version=$(echo $mozcsrcdir | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/')


if [ $(cat ~/.mozc_ut_install) = "$mozc_version" ]
	echo "UT dic patched mozc is already installed."
 	exit
fi

# patch mozc dic


cat $dirname"/utdic/src/mozcdic-ut.txt" >> $mozcsrcdir"src/data/dictionary_oss/dictionary00.txt"

# build mozc
echo "build mozc"
apt-src build $inpmethod"-mozc"

# install mozc
echo "install mozc"
if [ "$inpmethod" = "fcitx5" ]; then
	sudo apt install fcitx5 -y -qq
else
	if [ "$inpmethod" = "fcitx" ]; then
 		:
   	else
    		sudo apt remove *fcitx* -y -qq
      		sudo apt install $inpmethod -y -qq
      	fi
fi
if [ "$build" = "2" ]; then
	rm -f *dbgsym*
	sudo dpkg -i ./$inpmethod"-mozc"*.deb
	sudo dpkg -i ./mozc-server*.deb
	sudo apt-mark hold $inpmethod"-mozc"
 	sudo apt-mark hold mozc-server
  	echo $mozc_version > ~/.mozc_ut_install 
fi
# clean
if [ "$build" = "2" ]; then
	rm -rf $dirname
else
	echo "build deb dir is"$dirname
fi
echo "done."
