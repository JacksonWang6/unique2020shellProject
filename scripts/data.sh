#!/bin/bash
#这个模块提供了数据的迁移, 数据的备份, 数据文件夹的改变, 数据校验等数据处理功能

dataDir="${home}/data"
if [ -f "${home}/config.yml" ]; then
    dataDir=$(grep dataDir "${home}/config.yml" | sed 's/[ ]*//g' | awk -F ":" '{print $2}')
fi
#如果数据文件夹不存在, 那么就创建一个
if [ ! -d "$dataDir" ]; then
    mkdir "$dataDir"
    chmod 700 "${dataDir}"
fi

#默认是当前目录下面的backup文件夹, 如何指定我还没想出来...QwQ
backupDir=${home}"/backup"
if [ ! -d "$backupDir" ]; then
    mkdir "$backupDir"
fi


#这是一个存校验码的文件夹
checkDir=${home}"/check"
#如果校验文件夹不存在, 那么就创建一个
if [ ! -d "$checkDir" ]; then
    mkdir "$checkDir"
fi

#这里是校验文件
checkFile=${checkDir}"/checkFile.log"
if [ ! -f "${checkFile}" ]; then
    touch "${checkFile}"
fi

#还没有加入权限机制
#迁移数据到另一个文件夹
moveDataToAnotherDir() {
    echo -e "请输入目标文件夹\n"
    read -r targetDir
    if [ ! -d "${targetDir}" ]; then
        mkdir "${targetDir}"
        chmod 700 "${targetDir}"
    fi
    #避免输入了一个相对路径
    cd "${targetDir}" || { echo -e "cd ${targetDir} 失败!\n"; exit 1; }
    targetDir=$(pwd)
    flist=$(ls ${dataDir})
    for file in ${flist}; do
        mv "${dataDir}/${file}" "${targetDir}"
    done
    #改变脚本的数据文件夹
    dataDir=${targetDir}
    echo "dataDir: ${dataDir}" > "${home}/config.yml"
}

#备份数据, 后面跟了一个参数, 就是待备份的文件名
#重构了一下, 现在支持备份多个数据了
backupData() {
    if [  ! -d "${backupDir}" ] ;then
        mkdir "${backupDir}"
    fi
    #首先检查参数是否为0
    if [ $# -eq 0 ]; then
        echo -e "参数错误\n"
        exit
    fi

    echo -e "开始备份...\n"
    flist=$(ls "${dataDir}")
    #获取参数列表
    for par in "$@"
    do
        exist=0
        for file in ${flist}
        do
            if [ "${par}" == "${file}" ]
            then
                exist=1
                break
            fi
        done
        #如果这个在数据文件夹中存在
        if [ ${exist} -eq 1 ]
        then 
            cp -i "${dataDir}/${par}" "${backupDir}"
        else 
            echo -e "数据文件夹中不存在文件${par}, 备份失败\n"
        fi
    done
    echo -e "备份结束!\n"
}

#上面只是备份一个数据, 在添加进去的时候就备份了, 这个就是把整个备份的文件夹打成tar包
backupAndTar() {
    echo -e "请输入你想要打包到哪个目录: \n"
    read -r tarDir
    if [ ! -d "${tarDir}" ]; then
        mkdir "${tarDir}"
    fi
    cd "${tarDir}" || { echo -e "cd ${tarDir} 失败!\n"; exit 1; }
    tarDir=$(pwd)

    echo -e "请输入你想要打包成的文件名: \n"
    read -r fileName

    echo -e "正在打包!"
    #打成tar包
    tar -cvf "${tarDir}/${fileName}" "${backupDir}"
    echo -e "打包成功!"
}

#辅助函数, 每次运行完脚本后都会校验文件较上次结束是否发生变化
#这里应该是运行脚本后, 校验所有文件是否发生了变化...
#那么应该维护一个数据结构(好吧, shell貌似没有struct, 如果用两个数组来模拟, 可能系统关闭了, 数据就没了, 还是文件靠谱... 
#那就一个文件吧QwQ), 用来保存每一个文件的MD5校验码...
#运行结束之后再来计算每一个文件的校验码, 并对比前一次记录的...然后更新检验码文件
check() {
    #如果不存在, 那么创建一个, 存在的话就更好...
    touch "${checkFile}"
    #然后遍历数据文件夹, 以id为键, 文件的MD5校验码为值
    #由于我定义的文件名为id.json, 故处理起来相对简单, 虽然可扩展性极差...
    flist=$(ls "${dataDir}")
    cd "${dataDir}" || { echo -e "cd ${dataDir} 失败!\n"; exit 1; }
    for file in ${flist}
    do
        md5=$(md5sum "${file}")
        md5Arr=( $md5 )
        m=${md5Arr[0]} #m里面存储的是这个文件的md5编码
        id=${md5Arr[1]} #id里面存储的是这个人的id.json
        #一开始把grep命令的参数顺序搞反了...
        last=$(grep "${id}" "${checkFile}")
        #如果为空
        if [ -z "${last}" ]; then 
            echo -e "==============================================\n"
            echo "新增了文件${id}"
            echo -e "==============================================\n"
        else 
            lastArr=( $last )
            #这里一开始把美元$搞忘了...
            lastMd5=${lastArr[0]}
            #如果MD5值不相等
            if [ "${m}" != "${lastMd5}" ]; then
                echo -e "==============================================\n"
                echo "文件${id}被修改"
                echo -e "==============================================\n"
            fi
        fi
        #这里是先把这次的MD5信息记录到一个临时文件夹里面, 之后直接复制过去覆盖实现日志更新操作
        echo "${md5}" >> "checkFile.log"
    done

    #接下来检查是否有文件被删除?, 现在lastfList里面存储的是上次日志里面的人的id
    lastfList=$(awk '{print $2}' "${checkFile}")
    for lastFile in ${lastfList}
    do 
        result=$(echo "${flist}" | grep "${lastFile}")
        if [[ "${result}" == "" ]]; then
            echo -e "==============================================\n"
            echo -e "注意!!!文件${lastFile}被删除!\n"
            echo -e "==============================================\n"
        fi
    done
    #-f参数强制覆盖
    mv -f "checkFile.log" "${checkDir}"
}

#从备份的数据还原的函数, 传入的参数为待还原的文件名, 默认恢复到数据文件夹中
recover() {
    #$#获得所有参数的数目, 只是为了练一下case和$#才这样写的^_^
    case $# in
        0)
        echo -e "参数错误\n"
        exit "$E_BADARGS"
        esac


    echo -e "正在执行还原操作...\n"
    #$@获得所有参数列表
    flist=$(ls "${backupDir}")
    for par in "$@"
    do   
        #首先判断这个文件是否存在备份
        for list in ${flist}
        do
            if [ "${par}" == "${list}" ]; then
                #执行复制操作, 如果数据文件夹存在这个的话, 会提示是否覆盖
                cp -i "${backupDir}/${list}" "${dataDir}"
                echo -e "${list}还原成功!\n"
            fi
        done
    done
    echo -e "还原操作执行完成\n"
}

removeFile() {
    if [ "$#" -eq 0 ]; then
        echo -e "参数不能为空!\n"
        return
    fi

    for par in "$@"; do
        filePath="${dataDir}/${par}"
        if [ ! -f "${filePath}" ]; then
            echo -e "文件${par}不存在, 删除失败!\n"
            continue
        fi
        rm -rf "${filePath}"
        echo -e "删除文件${par}成功!\n"
    done
}