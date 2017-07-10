# 添加所需 R 包位置
.libPaths( unique(c( .libPaths(), "F:/VectorF/Documents/R/win-library/3.3") ))
# 载入包
library(RSelenium)
library(rvest)
library(stringr)
library(methods)
# 连接 Server
remDr <- remoteDriver(remoteServerAddr = "127.0.0.1" ,
                      port = 4444,
                      browserName = "chrome"
)
# 打开浏览器
remDr$open()
# 打开目标网页
remDr$navigate("https://movie.douban.com/")
# 设置搜索词
# 设定运行 Rscript 命令时传入参数
## keyword<- "鹿晗"
keyword<- commandArgs(T)
# 定位网页元素
SearchBox <- remDr$findElement(using='name', value='search_text')
# 传入关键词和回车
SearchBox$sendKeysToElement(list(keyword, key = 'enter'))
# 传入网页中所有的电影元素，将提取文本过程写成 MovieDataFunc 函数
MovieDataFunc<-function(MovieList)lapply(MovieList,function(i){
  # 读取每部电影的元素
  doc<-i$getElementAttribute("outerHTML")[[1]]%>%
    read_html()
  # 得到电影名 name
  name<-doc%>%
    html_nodes("a")%>%
    html_text()%>%
    str_replace_all(pattern="\\s",replacement="")
  # 得到评分 rate
  rate<-doc%>%
    html_nodes("span.rating_nums")%>%
    html_text()
  # 得到评分人数 pl
  pl<-doc%>%
    html_nodes("span.pl")%>%
    html_text()%>%
    str_extract(pattern="[:digit:]+")
  # 如果缺少评分或评分人数，则设置其为 NA
  rate<-ifelse(identical(rate,character(0)),NA,rate)
  pl<-ifelse(identical(pl,character(0)),NA,pl)
  # 返回电影名、评分和评分人数
  return(c(name,rate,pl))
}
)
# 定位到第一页的所有电影元素
MovieList <- remDr$findElements('class','pl2')
# 得到第一页的电影信息
MovieData<-MovieDataFunc(MovieList)
# 得到剩余网页信息
RemainPage <- remDr$findElements('xpath','//*[@id="content"]/div/div[1]/div[3]/a')
# 爬取剩余网页的电影信息
for(i in 1:length(RemainPage)){
  # 定位到”后页“
  NextPage <- remDr$findElement('css', '[class="next"]')
  # 模拟“点击”行为
  NextPage$clickElement()
  # 定位到当前网页的所有电影元素
  MovieList <- remDr$findElements('class','pl2')
  # 爬取当前网页的所有电影信息
  MovieData<-c(MovieData,MovieDataFunc(MovieList))
}
# 将 MovieData 的格式改为数据框，并更改列名
MovieData<-data.frame(t(sapply(MovieData,c)),stringsAsFactors = F)
colnames(MovieData)<-c("MovieName","Rate","RatePeopleNum")
# 创建 output 文件夹储存爬取结果，并将结果储存至相应的 .csv 文件中
if(!file.exists("output"))dir.create("output")
write.csv(MovieData,paste0("output/",keyword,"_moviedata.csv"),row.names = F)
# 关闭进程，退出浏览器
remDr$quit()