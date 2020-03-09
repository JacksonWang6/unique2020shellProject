#!/bin/bash
#这个模块提供了有关家族血统头衔等关系的处理

#这里是存放家族的文件
familyDir=${home}"/family"
if [ ! -d "${familyDir}" ]; then
    mkdir "${familyDir}"
fi

#这里是存放私生子的文件夹
greenHatDir=${home}"/greenHat"
if [ ! -d "${greenHatDir}" ]; then
    mkdir "${greenHatDir}"
fi

titlesFile="${familyDir}/titlesOfPeople.txt"
touch "${titlesFile}"
mainTitleFile="${familyDir}/mainTitleFile.txt"
touch "${mainTitleFile}"
finallySuccessorFile="${familyDir}/finallySuccessorFile.txt"
touch "${finallySuccessorFile}"

#查询某一个人属于哪一个家族
#@param: 传入一个参数, 人的id, 因为姓名可能会重复啊
queryFamily() {
    if [ "$#" -eq 0 ]; then
        echo -e "参数错误, 参数个数不能为0\n"
        return
    elif [ "$#" -gt 1 ]; then
        echo -e "只能接受一个参数!\n"
    fi

    id=$1
    file="${dataDir}/${id}.json"
    if [ ! -f ${file} ]; then
        echo -e "id为 ${id} 的人不存在!\n"
        return
    fi

    #代码解释: 首先grep抓取这一行, 然后将,"去掉, 然后以:为分隔符分成两段, 取第二段, 然后去除前后的空格, 不然文件名带有空格会出问题
    family=$(grep -i family "${file}" | sed 's/[,"]//g' |awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
    #如果为空
    if [ -z "${family}" ]; then
        echo -e "Unknown\n"
    else 
        echo "${family}"
    fi
}

#调用此函数, 将会将所有的人按照家族分类导出到另一个文件夹(familyDir)
#每个家族保存为一个文件, 每一行包含了一个家族成员的id和name
exportFamily() {
    #遍历dataDir下面的所有文件
    flist=$(ls ${dataDir})
    if [ -z "${flist}" ]; then
        echo -e "数据文件夹为空!导出失败!\n"
    fi

    echo -e "正在导出...\n"
    for file in ${flist}; do
        id=${file%%.*}
        family=$(queryFamily ${id})
        name=$(grep -i name "${dataDir}/${file}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
        if [ -z "${family}" ]; then
            wildman="${familyDir}/wildman.txt"
            echo -e "${id}\n" >> "${wildman}"
        fi
        familyFile="${familyDir}/${family}.txt"
        echo -e "${id} ${name}\n" >> "${familyFile}"
    done

    familyList=$(ls "${familyDir}")
    if [ -z "${familyList}" ]; then
        echo -e "家族文件夹为空!\n"
    fi

    #排序和去重
    for file in ${familyList}; do
        sort "${familyDir}/${file}" | uniq | sed '/^[ ]*$/d' > "${familyDir}/${file}"
    done
    echo -e "导出成功!\n"
}

#找出所有的私生子
greenHat() {
    greenHatFile="${greenHatDir}/greenHatFile.txt"
    touch "${greenHatFile}"
    flist=$(ls ${dataDir})
    if [ -z "${flist}" ]; then
        echo -e "数据文件夹为空!\n"
        return
    fi

    echo -e "正在统计私生子...\n"
    for file in ${flist}; do
        #首先获得这个人的性别, 如果是女的话就暂时不管她
        sex=$(grep -i sex "${dataDir}/${file}" | sed 's/[,"]//g;s/[ ]*//g' | awk -F ":" '{print $2}')
        if [ "${sex}" == "female" ]; then
            continue
        fi
        faId=${file%.*}
        faFamily=$(queryFamily ${faId})
        #获得儿子信息以及家族信息
        children=$(grep -i children "${dataDir}/${file}" | awk -F ":" '{print $2}' | sed 's/[,]/ /g;s/\[//g;s/\]//g' | sed 's/[ ]*/ /g')
        if [ -z "${children}" ]; then
            echo -e "id为${id}的人没有孩子\n"
        fi
        #孩子的数组拿到了
        childrenArr=( ${children} )
        for child in "${childrenArr[@]}"; do
            childFile="${dataDir}/${child}.json"
            if [ ! -f "${childFile}" ]; then
                echo -e "孩子${child}不存在"
                continue
            fi
            childFamily=$(queryFamily ${child})
            if [ "${childFamily}" != "${faFamily}" ]; then
                childName=$(grep -i name "${childFile}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
                echo -e "${child} ${childName}\n" >> "${greenHatFile}"
            fi
        done
    done
    #删掉空行
    cat ${greenHatFile} | sed '/^$/d' | uniq > "${greenHatFile}"

    base64Dir="${greenHatDir}/base64Dir"
    if [ ! -d "${base64Dir}" ]; then
        mkdir "${base64Dir}"
    fi

    #我这里之所以这样处理是因为我发现如果直接加密一个文件的话, 所有的加密字符会连在一起, 所以就这样又遍历里一遍QwQ
    base64File="${base64Dir}/base64.txt"
    while read line; do
        echo "${line}" | base64 >> "${base64File}"
    done < "${greenHatFile}"
    
    lines=$(wc -l "${base64File}" | awk -F " " '{print $1}')
    line=$((${lines}/10)) ; if [ ${line} -eq 0 ]; then line=1; fi; cd ${base64Dir} #这里cd进这个目录是因为我不知道split如何指定输出到哪个目录QwQ
    #代码解释, 这一行代码非常复杂, 第一条就是split指定顺序号是四位数字, 前缀是base_, 然后ls这个目录结果作为grep的参数提取含有base_行的, 进行重命名加上后缀.txt
    split -l ${line} "${base64File}" -d -a 4 base_&&ls | grep base_ | xargs -n1 -i{} mv {} {}.txt

    tar -cvf "${greenHatDir}/greenHatBase.tar" "${base64Dir}"
    echo -e "统计成功!\n"
}

#下面关于头衔的部分有一些疑问, 还没有开始编写 update: 已经编写完成
#将所有头衔和最终继承到它们的人导出到另一个文件，格式为每行头衔名，继承者id和继承者name。需要按id从小到大排序。
# 数据保证只有没有父母的人有头衔
# 主头衔继承父亲
# 私生子和正常孩子没有区别
# children第一个就是长子

#!/bin/sh
solve () {
    id=$1;               echo -e "solve ${id}"   
    file="${id}.json"
    filePath="${dataDir}/${file}"
    titles=$(grep -i titles "${filePath}" | sed 's/["]//g;s/\[//g;s/\]//g'| awk -F ":" '{print $2}')
    mainTitle=$(grep -i maintitle "${filePath}" | sed 's/[,"]//g; s/^[ ]*//g; s/[ ]*$//g' | awk -F ":" '{print $2}')
    name=$(grep -i name "${filePath}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
    titlesArr=()

    if [ -z "${titles}" ]; then
        #如果为空的话, 就查文件, 看看有没有, 要是还没有就跳过
        titles=$(grep -i "${id}" "${titlesFile}" | awk -F ":" '{print $3}')
        mainTitle=$(grep -i "${id}" "${mainTitleFile}" | awk -F ":" '{print $3}')
        if [ -z "${titles}" ]; then
            return
        fi
        OLD_IFS="$IFS"; IFS=","
        #现在就获得了titles数组
        titlesArr=($titles); IFS=${OLD_IFS}
    else
        OLD_IFS="$IFS"; IFS=","
        #现在就获得了titles数组
        titlesArr=($titles); IFS=${OLD_IFS}
        titlesNum=${#titlesArr[@]}
        line=$(grep -n "^${id}:" "${titlesFile}" | awk -F ":" '{print $1}')
        #这个人如果没有被写入文件的话, 那么就把他写入文件, 避免重复写入
        if [ -z "${line}" ]; then
            echo -e "${id}:${name}:${titlesArr[0]}\c" >> "${titlesFile}"
            for((i=1;i<titlesNum;i++)){
                echo -e ",${titlesArr[$i]}\c" >> "${titlesFile}"
            }
            echo "" >> "${titlesFile}"
            echo -e "${id}:${name}:${mainTitle}" >> "${mainTitleFile}"
        fi
    fi

    #能运行到这里就说明titles数组拿到了, 而且不为空^_^
    children=$(grep -i children "${filePath}" | awk -F ":" '{print $2}' | sed 's/\[//g;s/\]//g' | sed 's/[ ]*//g')
    OLD_IFS="$IFS"; IFS=","
    #现在就获得了titles数组
    childrenArr=($children)
    childrenNum=${#childrenArr[@]}
    #接下来判断这个人的性别id
    sex=$(grep -i sex "${filePath}" | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}')
    couples=$(grep -i couples "${filePath}" | awk -F ":" '{print $2}' | sed 's/\[//g; s/\]//g; s/ //g; s/,$//' )
    couplesArr=( $couples ); IFS=${OLD_IFS}
    #检查有无配偶, 配偶都没有肯定没有孩子, 直接跳过就行了
    if [ -z "${couples}" ]; then
        return
    fi

    #再检查有无子孙, 子孙都没有谈何继承, 跳过就行了
    if [ -z "${children}" ]; then
        return
    fi

    #检查孩子中是否有男性, 如果有男性的话, 女性在继承时直接跳过
    hasMale=0 #这是一个标记是否有男性的变量
    for child in "${childrenArr[@]}"; do
        childPath="${dataDir}/${child}.json"
        _sex=$(grep -i sex "${childPath}" | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}')
        if [ "${_sex}" == "male" ]; then
            #有男性, 标记一下
            hasMale=1
        fi
    done

    #如果长子是男性, 那么再标记一下除了长子外是否还有男性
    flag=0
    for((i=1;i<childrenNum;i++)){
        childPath="${dataDir}/${childrenArr[$i]}.json"
        _sex=$(grep -i sex "${childPath}" | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}')
        if [ "${_sex}" == "male" ]; then
            #有男性, 标记一下
            flag=1
        fi
    }

    #如果这个祖先是男性, 那么这里需要处理maintitles机制
    if [ "${sex}" == "male" ]; then
        #获取父亲的头衔
        faTitlesNum=${#titlesArr[@]}

        #首先把主头衔分给长子, 由于长子只能分一个头衔, 所以后面就当做女性对待, 直接跳过 update: 前面理解错了题意, 母亲的长子依旧继承母亲
        _id=${childrenArr[0]}
        _name=$(grep -i name "${dataDir}/${_id}.json" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')

        line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')

        if [ -z "${line}" ]; then
            echo -e "${_id}:${_name}:${mainTitle}" >> "${titlesFile}"
        else 
            sed -i "${line}s/$/,${mainTitle}/" "${titlesFile}"
        fi

        line=$(grep -n "^${_id}:" "${mainTitleFile}" | awk -F ":" '{print $1}')
        if [ -z "${line}" ]; then
            echo -e "${_id}:${_name}:${mainTitle}" >> "${mainTitleFile}"
        else
            #替换整行
            sed -i "${line}s/^.*$/${_id}:${_name}:${mainTitle}/" "${mainTitleFile}"
        fi
        
        #如果只有一个孩子, 那么直接跳过, 因为无论如何, 长子只会继承父亲的main头衔
        if [ "$childrenNum" -eq 1 ]; then
            #这样就可以跳过了
            faTitlesNum=1
        fi
        #j从1开始是因为长子不参与后续分配了
        #i代表头衔下标, j代表孩子的下标
        for ((i=0, j=1; i<faTitlesNum; i++, j++)) {
                    echo "paodaozhe${i}, ${faTitlesNum}"
            #继续依次分配
            if [ "$j" -eq "${childrenNum}" ]; then
                j=1
            fi
            _title=${titlesArr[$i]}
            #遇到主头衔直接跳过
            if [ "${_title}" == "${mainTitle}" ]; then
                continue
            fi
            #子孙有男性
            if [ "${hasMale}" -eq 1 ]; then
                if [ "${flag}" -eq 0 ]; then
                    break
                fi
                _id=${childrenArr[$j]}
                childPath="${dataDir}/${_id}.json"
                _sex=$(grep -i sex "${childPath}" | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}')
                _name=$(grep -i name "${childPath}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
                #如果是女性, 那么就得跳过, 这里不可能遇见长子了, 所以不判断长子
                if [ "${_sex}" == "female" ]; then
                    i=$((i-1))  #i--代表这个头衔不予以分配
                    continue
                fi

                #运行到这里说明分配该头衔给当前的孩子
                #首先检查文件里面是否已经有这个孩子的信息, 有的话就直接利用sed在行尾添加, 不然的话就新加一行喽
                #先拿到行号, 之所以我选择取得行号是为了方便后面的sed直接在源文件中进行修改
                _line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')
                if [ -z "${_line}" ]; then
                    #直接添加一行
                    echo -e "${_id}:${_name}:${_title}" >> "${titlesFile}"
                else
                    #否则在源文件中的这一行的后面添加对应的头衔
                    sed -i -e "${_line}s/$/,${_title}/" "${titlesFile}"
                fi
            else
                #否则子孙里面没有男性, 也就是说全部是女性, 那么女性拥有继承权
                _id=${childrenArr[$j]}
                childPath="${dataDir}/${_id}.json"
                _name=$(grep -i name "${childPath}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
                _line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')
                if [ -z "${_line}" ]; then
                    #直接添加一行
                    echo -e "${_id}:${_name}:${_title}" >> "${titlesFile}"
                else
                    #否则在源文件中的这一行的后面添加对应的头衔
                    sed -i -e '${_line}s/$/,${_title}/' "${titlesFile}"
                fi
            fi
        }
    else 
        #获取母亲的头衔
        maTitlesNum=${#titlesArr[@]}

        #首先把主头衔分给长子, 由于长子只能分一个头衔, 所以后面就当做女性对待, 直接跳过 update: 前面理解错了题意, 母亲的长子依旧继承母亲
        _id=${childrenArr[0]}
        _name=$(grep -i name "${dataDir}/${_id}.json" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
        #我这里没有进行检验的原因是长子只会分配这一次, 不会有第二次
        line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')
        if [ -z "${line}" ]; then
            echo -e "${_id}:${_name}:${mainTitle}" >> "${titlesFile}"
        else 
            sed -i -e "${line}s/$/,${mainTitle}/" "${titlesFile}"
        fi

        line=$(grep -n "^${_id}:" "${mainTitleFile}" | awk -F ":" '{print $1}')
        if [ -z "${line}" ]; then
            echo -e "${_id}:${_name}:${mainTitle}" >> "${mainTitleFile}"
        fi
        
        #如果只有一个孩子, 那么直接跳过
        if [ "$childrenNum" -eq 1 ]; then
            #这样就可以跳过了
            faTitlesNum=1
        fi
        #j从1开始是因为长子不参与后续分配了
        #i代表头衔下标, j代表孩子的下标
        for ((i=0, j=1; i<maTitlesNum; i++, j++)) {
            #继续依次分配
            if [ "$j" -eq "${childrenNum}" ]; then
                j=1
            fi
            _title=${titlesArr[$i]}
            #遇到主头衔直接跳过
            if [ "${_title}" == "${mainTitle}" ]; then
                continue
            fi
            #子孙有男性
            if [ "${hasMale}" -eq 1 ]; then
                if [ "${flag}" -eq 0 ]; then
                    break
                fi
                _id=${childrenArr[$j]}
                childPath="${dataDir}/${_id}.json"
                _sex=$(grep -i sex "${childPath}" | sed 's/[,"]//g; s/[ ]*//g' | awk -F ":" '{print $2}')
                _name=$(grep -i name "${childPath}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
                #如果是女性, 那么就得跳过, 这里不可能遇见长子了, 所以不判断长子
                if [ "${_sex}" == "female" ]; then
                    i=$((i-1))  #i--代表这个头衔不予以分配
                    continue
                fi

                #运行到这里说明分配该头衔给当前的孩子
                #首先检查文件里面是否已经有这个孩子的信息, 有的话就直接利用sed在行尾添加, 不然的话就新加一行喽
                #先拿到行号, 之所以我选择取得行号是为了方便后面的sed直接在源文件中进行修改
                _line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')
                if [ -z "${_line}" ]; then
                    #直接添加一行
                    echo -e "${_id}:${_name}:${_title}" >> "${titlesFile}"
                else
                    #否则在源文件中的这一行的后面添加对应的头衔
                    sed -i -e "${_line}s/$/,${_title}/" "${titlesFile}"
                fi
            else
                #否则子孙里面没有男性, 也就是说全部是女性, 那么女性拥有继承权
                _id=${childrenArr[$j]}
                childPath="${dataDir}/${_id}.json"
                _name=$(grep -i name "${childPath}" | sed 's/[," ]//g' | awk -F ":" '{print $2}' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g')
                _line=$(grep -n "^${_id}:" "${titlesFile}" | awk -F ":" '{print $1}')
                if [ -z "${_line}" ]; then
                    #直接添加一行
                    echo -e "${_id}:${_name}:${_title}" >> "${titlesFile}"
                else
                    #否则在源文件中的这一行的后面添加对应的头衔
                    sed -i -e "${_line}s/$/,${_title}/" "${titlesFile}"
                fi
            fi
        }
    fi       
}

#需要数据结构, 一个每一行是 id:name:[头衔] 格式的文件, 头衔之间用逗号分隔, 即记录每个人的头衔情况, 取名titlesOfPeople.txt, 放在family文件夹下面
#由于这个头衔代表的是所掌辖的区域, 所以头衔应该不会出现父母重复的情况, 那么就直接sed喽
exportTitle () {
    flist=$(ls "${dataDir}")
    for file in ${flist}; do
        id=${file%.*}
        solve "${id}"
    done
}

#查询某个人最终会继承到的头衔
queryPeopleTitle() {
    num=$#
    if [ ${num} -eq 0 ]; then
        echo -e "参数错误, 参数不能为空!"
    fi
    echo -e "正在查询..."
    for id in "$@"; do
        titles=$(grep -i ${id} ${titlesFile} | awk -F ":" '{print $3}')
        mainTitle=$(grep -i ${id} ${mainTitleFile} | awk -F ":" '{print $3}')
        if [ -z "${titles}" ]; then
            echo -e "id为${id}的人没有头衔"
        else
            echo -e "id为${id}的人的主头衔是: \"${mainTitle}\""
            echo -e "id为${id}的人的所有头衔是是: [\c"
            OLD_IFS="$IFS"; IFS=","
            #现在就获得了titles数组
            titlesArr=($titles); IFS=${OLD_IFS}
            titlesNum=${#titlesArr[@]}
            for ((i=0;i<titlesNum;i++)){
                title=${titlesArr[$i]}
                if [ $i -eq $((titlesNum-1)) ]; then
                    echo -e "\"${title}\"]"
                else
                    echo -e "\"${title}\", \c"
                fi
            }
        fi
    done  
    echo -e "查询结束!"
}

#我这里之所以用了tmp文件是因为cmder下面的sort命令存在BUG, 毕竟不是原生的Linux环境, 实在没办法了QwQ
#导出所有头衔和它的最终继承者
exportFinallySuccessor() {
    tmp="${familyDir}/tmp.txt"
    tmp1="${familyDir}/tmp1.txt"
    tmp2="${familyDir}/tmp2.txt"
    tmp3="${familyDir}/tmp3.txt"
    touch "${tmp}" "${tmp1}" "${tmp2}" "${tmp3}"

    while read -r line; do
        id=$(echo "${line}" | awk -F ":" '{print $1}')
        name=$(echo "${line}" | awk -F ":" '{print $2}')
        titles=$(echo "${line}" | awk -F ":" '{print $3}')
        OLD_IFS="$IFS"; IFS=","
        #现在就获得了titles数组
        titlesArr=($titles); IFS=${OLD_IFS}
        for title in "${titlesArr[@]}"; do
            title=$(echo ${title} | sed 's/^[ ]*//; s/[ ]*$//')
            echo -e "${title}" >> "${tmp2}"
            echo -e "${id}:${title}:${name}" >> "${tmp}"
        done
    done < "${titlesFile}"

    #sort函数存在bug, 貌似接不了参数, 不然会把参数当做文件名处理提示输入文件指定了两次QwQ, 我由懒得在虚拟机里面配环境只能这样搞了
    sort "${tmp}" > "${tmp1}"
    sort "${tmp2}" | uniq > "${tmp3}"
    while read -r line; do
        line=$(echo "${line}" | sed 's/\n//g')
        res=$(grep -i "${line}" "${tmp1}" | awk 'END {print}')
        resId=$(echo "${res}" | awk -F ":" '{print $1}' | sed 's/\n//g')
        resName=$(echo "${res}" | awk -F ":" '{print $3}' |sed 's/\n//g')
        resTitle=$(echo "${res}" | awk -F ":" '{print $2}' | sed 's/\n//g')
        echo -e "${resTitle}:${resId}:${resName}" >> "${finallySuccessorFile}"
    done < "${tmp3}"

    rm -rf "${tmp}" "${tmp1}" "${tmp2}" "${tmp3}"
}

#查询某个头衔最终会被谁继承
queryFinallySuccessor() {
    num=$#
    if [ ${num} -eq 0 ]; then
        echo -e "参数错误, 参数不能为空!"
    fi
    echo -e "正在查询..."
    str="$@"
    OLD_IFS="$IFS"; IFS=","
    arr=(${str}); IFS=${OLD_IFS}

    for par in "${arr[@]}"; do
        res=$(grep -i "${par}" "${finallySuccessorFile}")
        id=$(echo "$res" | awk -F ":" '{print $2}')
        name=$(echo "$res" | awk -F ":" '{print $3}')
        if [ -z "${id}" ]; then
            echo -e "没有人继承${par}!"
        else
            echo -e "${id}:${name}最终继承了头衔${par}"
        fi
    done

    echo -e "查询结束!"
}