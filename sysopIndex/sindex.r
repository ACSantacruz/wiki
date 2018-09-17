# Set working directory
setwd("~/Documents/perl/wiki/sysopIndex")

library(ggplot2)
library(reshape2)
library(RColorBrewer)
suppressPackageStartupMessages(library(zoo))
library(scales)

# Import data
args=commandArgs(trailingOnly = TRUE)
#args=c('sindex.csv','monthly')
dm=read.csv(args[1],header=T)
# Reorder for ggplot
dm <- dm[,c(1,2,4,3,5)]
# Format dates and values, will be useful for scaling x-axis
dm[[1]] <- as.Date(as.yearmon(dm[[1]]))
dm$Total = dm$Total/1500
dm$Total.bot = dm$Total.bot/1500
# Two lines by melting
dm_melt = melt(dm, id = names(dm)[1])
# For line aesthetics
dm_melt$type <- ifelse(grepl("Total",dm_melt$variable), "total", "index")


# Theme modified from Max Woolf
# https://minimaxir.com/2015/02/ggplot-tutorial/
modfte_theme <- function() {
  # Generate colors with RColorBrewer
  palette <- brewer.pal("Greys", n=9)
  color.background = '#F8F8F8'
  color.grid.major = palette[5]
  color.axis.text = palette[8]
  color.axis.title = palette[8]
  color.title = palette[9]
  
  # Begin construction of chart
  theme_bw(base_size=8) +
    
    # Set the entire chart region to a light gray color
    theme(panel.background=element_rect(fill=color.background, color=color.background)) +
    theme(plot.background=element_rect(fill=color.background, color=color.background)) +
    theme(panel.border=element_rect(color=color.background)) +
    
    # Hide minor and ticks
    theme(panel.grid.major=element_line(color=color.grid.major,size=0.3)) +
    theme(panel.grid.minor=element_blank()) +
    theme(axis.ticks=element_blank()) +
    
    # Match legend to background
    theme(legend.background = element_rect(fill=color.background)) +
    theme(legend.key = element_rect(fill=color.background)) +
    theme(legend.text = element_text(size=8,color=color.axis.title)) +
    theme(legend.title = element_blank()) +
    theme(legend.margin = margin(0,0,0,-5)) +
    
    # Set title and axis labels
    theme(plot.title=element_text(size=10,color=color.title)) +
    theme(plot.title=element_text(hjust=0.5,face='bold')) +
    theme(plot.title=element_text(margin=margin(0,0,5,0,"pt"))) +
    theme(axis.text.x=element_text(size=8,color=color.axis.text)) +
    theme(axis.text.y=element_text(size=8,color=color.axis.text)) +
    theme(axis.title.x=element_text(size=9,color=color.axis.title, vjust=0)) +
    theme(axis.title.y=element_text(size=9,color=color.axis.title, vjust=0.5)) +
    #theme(axis.text.x = element_text(margin=margin(0,0,0,0,"pt"))) +
    #theme(axis.text.y = element_text(margin=margin(5,5,10,5,"pt"))) +
    theme(plot.caption = element_text(size=6, color=palette[6])) +
    
    # Plot margins
    theme(plot.margin = unit(c(0.35, 0.2, 0.3, 0.3), "cm"))
}
plot3 <- ggplot(dm_melt, aes_string(x = names(dm_melt[1]), y = names(dm_melt[3]), colour = names(dm_melt[2]), group = names(dm_melt[2]))) + geom_line(aes(linetype=variable)) +
  scale_x_date(date_labels = "%b %y",breaks=pretty_breaks(6)) +
  scale_y_continuous(breaks=pretty_breaks(6)) +
  labs(title=paste("Sysop index",args[2], sep=' - '),
       x=names(dm_melt)[1],
       y="S-index",
       caption="User:Amorymeltzer") +
  scale_linetype_manual(values=c("solid", "solid", "dotted", "dashed")) +
  modfte_theme() + scale_colour_manual(values=c('#4DAF4A','#984EA3','grey75','grey75'))
#options(warn = -1)
#plot3 <- plot3+scale_y_continuous(sec.axis = sec_axis(~.*1500, name = "Total actions", breaks=derive(),labels=comma))
#options(warn = 0)
plot3
ggsave("S-index.png", plot3, width=4.92, height=3)
