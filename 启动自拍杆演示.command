#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./启动模拟演示.command -selfieDemo -phoneFindAuthorized -featureTestControls
print '已打开“功能”窗口。模拟器默认已连接自拍杆，可设置远程拍照延时并测试反向找手机。'
