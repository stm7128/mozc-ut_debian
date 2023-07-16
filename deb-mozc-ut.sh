#!/bin/bash
set -e

# ランダムなディレクトリ名を生成してディレクトリを作成
dirname="/tmp/mozc-ut-"$(dd if=/dev/random bs=1 count=5 2> /dev/null | base64 | head -c 5)
mkdir $dirname
cd $dirname
pwd
del_tmpdir() {
	sudo rm -rf $dirname
}

if [ -z "$(grep -v "#deb-src" /etc/apt/sources.list | grep -v "#" | grep deb-src)" ]; then
	echo "deb-src リポジトリが有効になっていません。"
	del_tmpdir
	exit 1
fi

# 依存関係をチェック
installdep=""
if [ "$(which apt-src)" = "/usr/bin/apt-src" ]; then
	echo "apt-src が見つかりました。"
else
	echo "apt-src が見つかりません。\nインストールします。"
	installdep+="apt-src "
fi

if [ "$(which git)" = "/usr/bin/git" ]; then
	echo "git が見つかりました。"
else
	echo -e "git が見つかりません。\nインストールします。"
	installdep+="git "
fi

if [ "$(which ruby)" = "/usr/bin/ruby" ]; then
	echo "ruby が見つかりました。"
else
	echo -e "ruby が見つかりません。\nインストールします。"
	installdep+="ruby"
fi

# 依存関係をインストール
if [ "$installdep" ]; then
	echo "依存関係をインストール中。"
	sudo apt install $installdep -y -qq
fi

# 入力方式の選択
echo -e "入力方式\n・ibus\n・fcitx\n・fcitx5\n・uim\n・emacs"
read -p "インプットメソッドを選択してください: " inpmethod
read -p "選択したインプットメソッドは "$inpmethod" です。続ける場合は「y」を入力してください: " oyn
if [ "$oyn" = y ]; then
	:
else
	del_tmpdir
	exit 0
fi
echo -e "ビルドのみ: 1\nビルドとインストール: 2"
read -p "番号を入力してください: " build
# 辞書のビルド
echo "mozc-ut 辞書をビルドしています" 
git clone https://github.com/utuhiro78/merge-ut-dictionaries.git utdic
cd utdic/src
chmod +x ./make.sh
./make.sh

# なんかいろいろ

mozc_version=$(apt search mozc-server 2> /dev/null|grep mozc-server|sed -E 's/.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/')


if [ $(cat ~/.mozc_ut_install) = "$mozc_version" ]; then
	echo "UT 辞書パッチ済みの Mozc はすでにインストールされています。"
 	exit
else
	sudo apt-mark unhold $inpmethod"-mozc"
 	sudo apt-mark unhold mozc-server
fi


# Mozc ソースのダウンロード
echo "Mozc ソースをダウンロードしています"
cd $dirname
sudo apt-src update
apt-src install mozc
mozcsrcdir=$dirname"/"$(ls -d *mozc*/|sed -e s@/@@)"/"


# Mozc 辞書へのパッチ適用
cat $dirname"/utdic/src/mozcdic-ut.txt" >> $mozcsrcdir"src/data/dictionary_oss/dictionary00.txt"

# Mozc のビルド
echo "Mozc をビルドしています"
apt-src build $inpmethod"-mozc"

# Mozc のインストール
echo "Mozc をインストールしています"
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
# クリーンアップ
if [ "$build" = "2" ]; then
	rm -rf $dirname
else
	echo "ビルドしたディレクトリ: $dirname"
fi
echo "完了"
