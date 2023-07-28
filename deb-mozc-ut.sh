#!/bin/bash
set -e

# ランダムなディレクトリ名を生成してディレクトリを作成
dirname="/tmp/mozc-ut-"$(dd if=/dev/random bs=1 count=5 2> /dev/null | base64 | head -c 5)
mkdir $dirname
cd $dirname
pwd
cleanup() {
  echo "クリーンアップ中..."
  sudo rm -rf "$dirname"
}

# シグナルのハンドリング
trap cleanup EXIT INT TERM

if [ -z "$(grep -v "#deb-src" /etc/apt/sources.list | grep -v "#" | grep deb-src)" ]; then
	echo "deb-src リポジトリが有効になっていません。"
	cleanup
	exit 1
fi

# 依存関係をチェック
dependencies=("apt-src" "git" "ruby")
missing_dependencies=()
for dependency in "${dependencies[@]}"; do
  if ! command -v "$dependency" >/dev/null; then
    missing_dependencies+=("$dependency")
  fi
done

if [ ${#missing_dependencies[@]} -gt 0 ]; then
  echo "以下の依存関係が見つかりませんでした: ${missing_dependencies[*]}"
  echo "依存関係をインストールします..."
  sudo apt install "${missing_dependencies[@]}" -y  > /dev/null 2>&1
fi



# 入力方式の選択
input_methods=("ibus" "fcitx" "fcitx5" "uim" "emacs")
echo -e "入力方式: ${input_methods[*]}"
read -p "インプットメソッドを選択してください: " inpmethod
if [[ ! " ${input_methods[*]} " =~ " ${inpmethod} " ]]; then
  echo "無効な入力方式が選択されました。"
  exit 1
fi

mozc_version=$(apt search mozc-server 2> /dev/null|grep mozc-server|sed -E 's/.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/')


if [ $(cat ~/.mozc_ut_install 2> /dev/null) = "$mozc_version" ]; then
	echo "UT 辞書パッチ済みの Mozc は既にインストールされています。"
 	exit
else
	sudo apt-mark unhold $inpmethod"-mozc"
 	sudo apt-mark unhold mozc-server
fi

read -p "$inpmethod が選択されました。よろしいですか？ [y/N]: " oyn

if [ "$oyn" = y ]; then
	:
else
	cleanup
	exit 0
fi
echo -e "ビルドのみ: 1\nビルドとインストール: 2"
read -p "番号を入力してください: " build
# 辞書のビルド
echo "mozc-ut 辞書をビルドしています..." 
git clone https://github.com/utuhiro78/merge-ut-dictionaries.git utdic > /dev/null 2>&1
cd utdic/src
chmod +x ./make.sh
./make.sh > /dev/null 2>&1

# Mozc ソースのダウンロード
echo "Mozc ソースをダウンロードしています..."
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
	sudo apt remove gir1.2-fcitx-1.0 libfcitx-config4 libfcitx-core0 libfcitx-gclient1 libfcitx-utils0 -y > /dev/null 2>&1
	sudo apt install fcitx5 -y -qq > /dev/null 2>&1
else
	if [ "$inpmethod" = "fcitx" ]; then
 		:
   	else
		sudo apt remove gir1.2-fcitx-1.0 libfcitx-config4 libfcitx-core0 libfcitx-gclient1 libfcitx-utils0 -y  > /dev/null 2>&1
		sudo apt install $inpmethod -y > /dev/null 2>&1
      	fi
fi
if [ "$build" = "2" ]; then
	rm -f *dbgsym*
	sudo apt install ./$inpmethod"-mozc"*.deb
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
