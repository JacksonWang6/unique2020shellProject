#!/bin/bash
#这个模块提供了从一个文件夹导入数据, 从已经打包好的数据导入以及手动导入数据的功能

#从命令行读取用户信息存到json文件中, 文件名的格式为${id}.json
#这里存在一个BUG, 就是数组里面多了一个逗号, 不知道有什么好办法消掉...
#update
saveToJson () {
    echo -e "请输入你的个人信息\n"
    echo -e "请输入你的姓名: \n"
    #注意: 这里的-r参数代表屏蔽转义, 因为用户层面上面来讲它并不知道转义这个东西
    read -r name
    echo -e "请输入你的id: \n"
    read -r id
    echo -e "请输入你的性别: \n"
    read -r sex
    echo -e "请输入你的配偶, 若有多个用空格隔开: \n"
    read -r couples
    #OLD_IFS="$IFS" #保存旧的分隔符
    #IFS=" ", 因为默认的分隔符就是空格, 制表符
    couplesArr=( $couples )
    couplesNum=${#couplesArr[@]}
    #IFS="$OLD_IFS" # 将IFS恢复成原来的
    # for i in "${!couplesArr[@]}"; do
    #     echo "$i=>${couplesArr[i]}"
    # done

    echo -e "请问您是否有家族?(y/n)\n"
    read familyOption
    if [ "${familyOption}" == "y" ]; then
        echo -e "请输入你的家族: \n"
        read -r family
    fi
    echo -e "请输入你的子嗣, 如果有多个用空格隔开: \n"
    read -r children
    childrenArr=( $children )
    childrenNum=${#childrenArr[@]}
    echo -e "请问您是否有头衔?(y/n)\n"
    read titlesOption
    if [ "${titlesOption}" == "y" ]; then
        echo -e "请输入你的主头衔: \n"
        read -r maintitle
        echo -e "请输入你的所有头衔: \n"
        read -r titles
        titlesArr=( $titles )
        titlesNum=${#titlesArr[@]}
    fi 
    #接下来将这些变量按照Json的格式存进Json文件
    fileName="${dataDir}/${id}.json"
    touch "${fileName}"
    echo -e "{" >> "$fileName"
    echo -e "\t\"name\":\" ${name}\"," >> "$fileName"
    echo -e "\t\"id\": ${id}," >> "$fileName"
    echo -e "\t\"sex\":\" ${sex}\"," >> "$fileName"
    
    echo -e "\t\"couples\": [\c" >> "$fileName"
    for((i=0; i<couplesNum; i++)) {
        if [ $i -eq $[ ${couplesNum} - 1]  ]; then
            echo -e "${couplesArr[$i]}\c" >> "$fileName"
        else 
            echo -e "${couplesArr[$i]}, \c" >> "$fileName"
        fi
    }
    echo -e "]," >> "$fileName"
    if [ "${familyOption}" == "y" ]; then
        echo -e "\t\"family\":\" ${family}\"," >> "$fileName"
    fi 
    
    echo -e "\t\"children\": [\c" >> "$fileName"
    for((i=0; i<childrenNum; i++)) {
        if [ $i -eq $[ ${childrenNum} - 1 ] ]; then
            echo -e "${childrenArr[$i]}\c" >> "$fileName"
        else
            echo -e "${childrenArr[$i]}, \c" >> "$fileName"
        fi
    }
    if [ "${titlesOption}" == "n" ]; then
        echo -e "]" >> "$fileName"
    else 
        echo -e "]," >> "$fileName"
    fi
    if [ "${titlesOption}" == "y" ]; then
        echo -e "\t\"maintitle\":\" ${maintitle}\"," >> "$fileName"
        echo -e "\t\"titles\": [\c" >> "$fileName"
        for((i=0; i<titlesNum; i++)) {
            if [ $i -eq $[ ${titlesNum} - 1 ] ]; then
                echo -e "\"${titlesArr[$i]}\"\c" >> "$fileName"
            else 
                echo -e "\"${titlesArr[$i]}\", \c" >> "$fileName"
            fi
            echo -e "]\c"
        }
    fi 
   
    echo -e "}" >> "$fileName"
}

importFromDir() {
    #首先进行参数检查
    if [ "$#" -eq 0 ]; then
        echo -e "参数错误, 请传入数据文件夹的路径!\n"
        return 0
    fi

    echo -e "开始导入...\n"
    #接下来对参数中的文件夹进行检查, 看是否存在...
    for par in "$@"; do
        if [ ! -d "${par}" ]; then
            echo "不存在文件夹${par}"
            continue
        fi
        #运行到这里的话就说明存在这个文件夹, 然后对这个文件夹里面的文件进行解析
        #首先避免是一个相对路径, 先把它换成一个绝对路径
        #cd "${par}" || { echo -e "cd ${par} 失败!\n"; exit 1; }; par=$(pwd)
        #获取文件列表
        flist=$(ls "${par}")
        #如果文件列表为空
        if [ -z "${flist}" ]; then
            echo -e "文件夹${par}为空"
            continue
        fi
        for file in ${flist}; do
            #目前我判断一个文件是否符合我的要求的原则是依据id字段, 只要含有我就认为它是合格的, 当然, 这样很不严谨
            res=$(grep -i id "${par}/${file}") #提取出包含id的行
            if [ -z "${res}" ]; then
                echo -e "文件${file}导入失败!原因: 不符合要求!\n"
                continue
            fi
            #然后用grep以及正则表达式把id字段提取出来, 因为我的文件名是以id.json命名的, 所以方便重命名
            id=$(echo ${res} | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}') #代码解释, 这一行相对复杂一点, sed将,和"去掉, awk以:为分隔符,并输出第二个字段
            #然后重命名并且复制过来
            mv "${par}/${file}" "${par}/${id}.json"
            cp "${par}/${id}.json" "${dataDir}"
        done
    done
    echo -e "导入过程结束!谢谢使用!\n"
}

#从已经打好的包中导入, 目前支持tar包, 其他的以后再说, 反正就是判断一下后缀, 加一点逻辑的事情
#@param: 可以有多个, 为tar包的路径
#勉强完成任务, 不过这个函数写的巨蠢, 以后还得重构
importFromTar() {
    #首先进行参数检查
    if [ "$#" -eq 0 ]; then
        echo -e "参数错误, 请传入打包好的数据的路径!\n"
        return 0
    fi
    #先保存一下当前的绝对路径
    now=$(pwd)

    echo -e "开始导入...\n"
    #接下来对参数中的文件夹进行检查, 看是否存在...
    for tarFile in "$@"; do
        #如果是tar包
        if [ "${tarFile##*.}" == "tar" ]; then
            res=$(echo ${tarFile} | grep "/")
            if [ -z "${res}" ]; then
                tarDir=$(pwd)
            else
                tarDir="${tarFile%/*}/"
            fi
            name=${tarFile%.*}; name=${name##*/}
            if [ ! -d "${tarDir}" ]; then
                echo -e "${tarDir}/${name}不存在\n"
                continue
            fi

            cd ${tarDir}; tarDir=$(pwd);
            if [ ! -d "${now}/${name}" ]; then
                mkdir "${now}/${name}"
            fi

            tar xvf "${tarDir}/${name}.tar" -C "${now}/${name}"
            cd "${name}/" || { echo -e "cd ${name} 失败!\n"; exit 1; }
            dirs=$(ls)
            
            for dir in ${dirs}; do
                importFromDir "${dir}"
            done
            cd ${now}
            rm -rf "${name}"
        fi
        echo -e "导入${tarFile}成功!\n"
    done
    echo -e "导入完成!\n"
}