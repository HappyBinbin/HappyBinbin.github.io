#!/bin/bash

# 指定目标目录，默认为当前目录
TARGET_DIR=${1:-.}

# 查找并删除文件的函数
delete_files() {
  local dir="$1"

  # 使用 find 查找文件，忽略大小写 (-iname)
  find "$dir" -type f \( -iname "readme" -o -iname "_sidebar" \) -print -exec rm -f {} \;
}

# 检查目录是否存在
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "目录 $TARGET_DIR 不存在！"
  exit 1
fi

# 调用删除函数
delete_files "$TARGET_DIR"

echo "符合条件的文件已删除。"
