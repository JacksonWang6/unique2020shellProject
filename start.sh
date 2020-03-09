#!/bin/bash
# shellcheck source=/dev/null
#@description: 这是一个启动脚本, 在这个里面实现交互式的逻辑

#这是存放脚本的路径, 一定要使用绝对路径, 如果换了一台机器使用此脚本记得要更改路径为你的机器上的脚本文件夹所在路径
scripts="/c/Users/44811/Desktop/shellProject/scripts"

#下面是一系列的初始化文件夹, 值得一提的是, 启动文件可以跟随一个参数, 这个参数就是你指定的数据文件夹哟
#脚本执行时需要接受一个参数, 就是需要操作的数据文件夹的目录, 如果不指定, 那么就是默认脚本所在得目录, 如果指定了多个, 那么抛出异常
if [ "$#" -eq 0 ]; then
    home=$(pwd) #如果没有传参, 默认当前目录为主目录
elif [ "$#" -eq 1 ]; then
    #先检查是否存在这个文件夹
    if [ ! -d "$1" ]; then
        mkdir "$1"
    fi
    #||后面接的是cd失败后的错误处理代码, 增强了代码的鲁棒性
    cd "$1" || { echo "cd $1 失败"; exit 1;}
    #避免传的是当前所在位置的一个相对路径
    home=$(pwd)
else
    #如果传了多个参数, 出现脑裂, 到底用哪个数据库??? 故抛出异常
    echo "参数传递错误"
    exit 1;
fi

#加载脚本文件
source "${scripts}/data.sh"
source "${scripts}/family.sh"
source "${scripts}/save.sh"

option=1
#下面开始交互式界面的编写
while [ ${option} != "0" -a  ${option} -gt "0" -a ${option} -le "15" ]
do
    clear
    echo -e "============================================================"
    echo -e "欢迎使用阿方索国人口管理系统!\n"
    echo -e "============================================================"
    echo -e "请输入你想使用的功能前面的序号使用对应的功能!\n"
    echo -e "   1. 迁移数据到另一个文件夹"
    echo -e "   2. 备份数据"
    echo -e "   3. 打包数据"
    echo -e "   4. 还原数据"
    echo -e "   5. 手动输入数据"
    echo -e "   6. 从另一个文件夹导入数据"
    echo -e "   7. 从已经打包好的数据中导入数据"
    echo -e "   8. 删除文件"
    echo -e "   9. 查询某人属于哪一个家族"
    echo -e "   10. 导出家族"
    echo -e "   11. 统计出所有人中的私生子"
    echo -e "   12. 导出头衔"
    echo -e "   13. 导出所有头衔和最终继承者"
    echo -e "   14. 查询某个人最终会继承到的头衔"
    echo -e "   15. 查询某个头衔最终会被谁继承到"
    echo -e "   other. exit"
    read -r option
    case ${option} in
    1)
        clear
        moveDataToAnotherDir
        ;;
    2)
        clear
        echo -e "请输入你想要备份的数据\n"
        read -r args
        backupData ${args}
        ;;
    3)
        clear
        backupAndTar
        ;;
    4)
        clear
        echo -e "请输入你想要还原的数据\n"
        read -r args
        recover ${args}
        ;;
    5)
        clear
        saveToJson
        ;;
    6)
        clear
        echo -e "请输入你想要导入数据的文件夹\n"
        read -r args
        importFromDir "${args}"
        ;;
    7)
        clear
        echo -e "请输入你想要导入的tar包\n"
        read -r args
        importFromTar ${args}
        ;;
    8)
        clear
        echo -e "请输入你想要删除的文件\n"
        read -r args
        removeFile "${args}"
        ;;
    9)
        clear
        echo -e "请输入你想要查询的人名"
        read -r args
        queryFamily "${args}"
        ;;
    10)
        clear
        exportFamily
        ;;
    11)
        clear
        greenHat
        ;;
    12)
        clear
        exportTitle
        ;;
    13)
        clear
        exportFinallySuccessor
        ;;
    14)
        clear
        echo -e "请输入你想要查询的人的id:"
        read -r args
        queryPeopleTitle "${args}"
        ;;
    15)
        clear
        echo -e "请输入你想要查询的头衔:"
        read -r args
        queryFinallySuccessor "${args}"
        ;;
    esac
    check
    printf "\nEnter any key to go back..."; 
	read -r a
done