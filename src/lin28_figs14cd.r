#' Systemically changing genes and developmental processes in embryonic stages.

#' For the definition of systemicall changing genes: see lin28.r.
# Number of systemically changing genes
# Load data of systemically changing genes
Sys.setenv(RSTUDIO_PANDOC="/Applications/RStudio.app/Contents/MacOS/pandoc")
knitr::opts_chunk$set(warning = FALSE)
load('allg_hs.rdata') # from lin28.r
par(cex=2,las=1,mar=c(2,4,3,1),lwd=3,pch=16,mfrow=c(2,2))
for(i in 1:4){
  ind<- list( 7:6, 5:4, 3:2, 1)[[i]]
  sp<- c('Zebrafish','Frog','Mouse','Human')
  if(i<4) plot_data<- cbind( sapply(allg_hs[[ind[1]]],length), sapply(allg_hs[[ind[2]]],length) ) else plot_data<- cbind(c(0,0),sapply(allg_hs[[ind[1]]],length))
  bar<-barplot( plot_data, col=c('blue','red'), beside=T, ylab='Number of genes', main=sp[i] , border=NA, names.arg=c('','') )
  text( apply(bar,2,mean), par('usr')[3]-(par('usr')[4]-par('usr')[3])/10, label=c(expression(1%->%2),expression(3 %->% 4)),xpd=NA)
}

# Expression pattern of systemically changing gens in human.
load('../../temporal2/code/temporal2.rdata')
plot_mx<- -clu_temp_fdo[ unlist(hs_glo) ,  rownames(clu_anno)[ rownames(clu_anno)%in% colnames(clu_temp_fdo)] ]
plot_mx[plot_mx>2]<-2
plot_mx[plot_mx< -2]<- -2
heatmap3( plot_mx,labRow=ge2an[rownames(plot_mx)],labRow2=NA,scale='none',dendrogram='none',trace='none',Rowv=F,Colv=F,symkey=F,density.info="none",keysize=1,col=colorRampPalette(c('blue',"white","red"))(499),color_key_label='log2 FD',color_key_label_cex=1,margins=c(0,0),color_key_axis_cex=1,key_mar=c(3, 0, 1, 1),labCol='',labRow_pos=c(2,4),sepwidth=c(0.1,0.1),sepcolor='black',cexRow=.2,lhei=c(1,5), ColSideColors= parts_col[ mg_chunk[colnames(plot_mx)] ],colsep=col_sep ,rowsep=sapply(c(1:2,4),function(x){ length(unlist(tempg_glog2[1:x]))}) )
rm(list=ls(all=T))

# Pathways that are positively correlated to the expression of LIN28A mRNA.
load('../../evo-devo/code/evo-devo2.rdata')
# Test GSEA datasets (Reactome) locally
cp_react<- scan('~/BaoLab/xuy/human/lin28/GSEA/c2.cp.reactome.v7.1.symbols.gmt',what=character(0),sep='\n')
tmp<- unname(sapply( cp_react, function(x){ strsplit(x, split='\t')[[1]][1] }))
cp_react<- lapply( cp_react, function(x){ strsplit(x, split='\t')[[1]][-(1:2)] })
names(cp_react)<- tmp
simp_gsea<- function(x){ paste( tolower(strsplit(x,split='_')[[1]][-1]), collapse=' ') }
rev_gsea <- function(x){ paste('REACTOME', gsub(' ','_',toupper(x)),sep='_') }

# Functions for enrichment test
test_enrich_logic2<- function( diag, test, total){ # logic 2 and 4 use the same function but different gene set
  y<- diag[ diag %in% total]
  x<- test[ test %in% total]
    test_mx<- matrix( c( sum( x %in% y), sum( x %in% setdiff(total,y) ), sum( y %in% setdiff(total,x)), sum( setdiff(total,x) %in% setdiff(total,y) ) ), nr=2)
    pv<- fisher.test(test_mx)$p.value
    return( c(pv, sum(x%in%y),length(y), sum(x%in%y)/length(x), length(y)/length(total), length(x) ) )
}
test_gsea<-function(my_gene, gset, backg){
  res<-t(sapply( gset, function(x){
    test_enrich_logic2( diag=my_gene, test=x, total= backg )
  }))
  res<- cbind( res, p.adjust( res[,1], method='BH')) # multi-testing correction
  return(res)
}
rm_react<- c(grep( 'DISEASE', names(cp_react),value=T), grep( 'DISORDER', names(cp_react),value=T), grep( 'HIV', names(cp_react),value=T), grep( 'VIRAL', names(cp_react),value=T), grep( 'VIRUS', names(cp_react),value=T)) # remove pathways that are disease-related
allg_gsea<-lapply( allg_updn, function(y){
  res<-test_gsea( my_gene= y, gset=cp_react[setdiff(names(cp_react),rm_react)], backg= intersect(ge2an,unique(hs_orth2[,2])) )
  print('done')
  return(res)
})
names(allg_gsea)<-c('hs_dp','mm_dp','mm_up','xt_dp','xt_up','dr_dp','dr_up')

# orgnize go terms of gene sets in one matrix
allg_siggl<- lapply( allg_sigg, function(x){ 
  if(length(x)==0) res1<-0 else{
    res1<- -round(log10(x[,7]),digit=1)
    names(res1)<- unname(sapply( rownames(x), simp_gsea ))
  }
  return( res1 )
})
allg_siggm<- sapply( allg_gsea, function(x){
  res<-x[ rev_gsea(sort(setdiff(unique( unlist( sapply(allg_siggl,names) ) ),''))) , 7]
  res<- -round(log10(res),digit=1)
  names(res)<- sapply( names(res), simp_gsea)
  return(res)
})

# divide into 2 groups: stage 1 to 2, and stage 3 to 4
gind<- lapply( c('up', 'dp'), function(x){ grep(x,names(allg_updn)) })
names(gind)<-c('up','dp')
allg_siggm4_ft<- lapply( gind, function(x, cut=4){ # cutoff of significant GO
  res<-allg_siggm[,x]
  res<- res[ unique(unlist( allg_sig_ft[x] )), ]
  res<- res[ apply(res,1,max)>=cut, ]
  res<- cbind(res, go_cate[rownames(res)])
  res<- res[ order( go_cate_od[res[,ncol(res)]], -apply( t(apply(res[,-ncol(res)],1,as.numeric)),1,max) ),]
  res<- res[ rownames(res) %in% names(go_cate) & (!rownames(res) %in% rm_go), ]
  return(res)
})

# Systemically changing genes hit in the enriched pathways
sigo<- unique(unlist(sapply( allg_siggm4_ft, rownames)))
sigo_dr<- sapply( sapply( sigo ,rev_gsea), function(x){ get_overlap_gene( gset=unique( unlist(allg_hs[6:7])), pr= intersect(unique(unlist(c(dr_dp_glo,dr_up_glo))), rownames(dr_all_exp)), go=x, ind=5) })
sigo_xt<-sapply( sapply( sigo ,rev_gsea), function(x){ get_overlap_gene( gset=unique(unlist(allg_hs[4:5])), pr= intersect(unique(unlist(c(xt_dp_glo,xt_up_glo))), rownames(xt_all_exp)), go=x, ind=3) })

# correlation between genes in significant pathways and LIN28A
sigo_dr_cor<- sapply(sigo_dr, function(x){ sapply(x, function(y){ cor( dr_all_exp[y,], dr_all_exp['ENSDARG00000004328',] )}) })
sigo_xt_cor<- sapply(sigo_xt, function(x){ sapply(x, function(y){ cor( xt_all_exp[y,], xt_all_exp['ENSXETG00000012324',] )}) })
drg_cor<- sapply( setdiff(rownames(dr_all_exp),'ENSDARG00000004328'), function(y){ cor( dr_all_exp[y,], dr_all_exp['ENSDARG00000004328',] )}) # remove LIN28A
xtg_cor<- sapply( setdiff(rownames(xt_all_exp),'ENSXETG00000012324'), function(y){ cor( xt_all_exp[y,], xt_all_exp['ENSXETG00000012324',] )})
xtg_cor[is.na(xtg_cor)]<-0
# significant test of correlation between genes in pathways and genome background
sigo_cor_test_pv<-cbind(sapply(sigo_dr_cor, function(x){ wilcox.test(x, drg_cor)$p.value }),
sapply(sigo_xt_cor, function(x){ wilcox.test(x, xtg_cor)$p.value }) )
# cutoffs for positively correlated pathways: p value < 0.001 & at least 10 genes with strong correlation (> 0.5 or < -0.5) in frog and zebrafish
(names(sigo_xt_cor)[sapply(sigo_xt_cor, function(x){ sum(x> .5)>=10}) & sapply(sigo_dr_cor, function(x){ sum(x> .5)>=10}) & apply(sigo_cor_test_pv,1,min)< .0001])
(names(sigo_xt_cor)[sapply(sigo_xt_cor, function(x){ sum(x> .5)>=10}) & sapply(sigo_dr_cor, function(x){ sum(x< -.5)>=10}) & apply(sigo_cor_test_pv,1,min)< .0001])
#' Three positively correlated pathways (RNA PolII related are redundancy with mRNA splicing). No negatively correlated pathways.

# get consistent genes in frog and zebrafish by fold difference and correlation
get_con_gene<- function(g1, g2, diff1, diff2, is_dn=T, ind1, ind2, orth=hs_orth2 , cor1, cor2, cut_cor=.5 ){
  g1<- g1[ g1 %in% names(diff1) ]
  comb1a<- diff1[g1]
  comb1b<-lapply(g1, function(x){
    gg<- intersect(unique(orth[ orth[,ind1]%in%x, ind2]), names(diff2))
    if(length(gg)==0) oth<-0 else oth<- diff2[gg[1]]
    return(oth)
  })
  comb1b<- do.call('c',comb1b)
  cor1a<- cor1[g1]
  cor1b<- cor2[names(comb1b)] 
  if(is_dn) res1<- list( names(comb1a)[comb1a>0&comb1b>0&cor1a>=cut_cor&cor1b>=cut_cor], names(comb1b)[comb1a>0&comb1b>0&cor1a>=cut_cor&cor1b>=cut_cor] ) else res1<- list( names(comb1a)[comb1a<0&comb1b<0&cor1a>=cut_cor&cor1b>=cut_cor], names(comb1b)[comb1a<0&comb1b<0&cor1a>=cut_cor&cor1b>=cut_cor] ) 
  g2<- g2[ g2 %in% names(diff2) ]
  comb2b<- diff2[g2]
  comb2a<-lapply(g2, function(x){
    gg<- intersect(unique(orth[ orth[,ind2]%in%x, ind1]), names(diff1))
    if(length(gg)==0) return(0) else return( diff1[gg[1]] )
  })
  comb2a<- do.call('c',comb2a)
  cor2a<- cor1[names(comb2a)] 
  cor2b<- cor2[g2]  
  if(is_dn) res2<- list( names(comb2a)[comb2a>0&comb2b>0&cor2a>=cut_cor&cor2b>=cut_cor], names(comb2b)[comb2a>0&comb2b>0&cor2a>=cut_cor&cor2b>=cut_cor] ) else res2<- list( names(comb2a)[comb2a<0&comb2b<0&cor2a>=cut_cor&cor2b>=cut_cor], names(comb2b)[comb2a<0&comb2b<0&cor2a>=cut_cor&cor2b>=cut_cor] ) 
  res<- list( unique(c(res1[[1]],res2[[1]])), unique(c(res1[[2]],res2[[2]])) )
  return(res)
}
dr_diff<- cbind( 
cal_wilp2( mx1=dr_all_exp[,c(4:5)], mx2=dr_all_exp[,7:8],cut_mean=10,small_val=1), #  up phase
cal_wilp2( mx1=dr_all_exp[,9:10], mx2=dr_all_exp[,16:17],cut_mean=10,small_val=1) #  down phase
) 
xt_diff<- cbind( 
cal_wilp2( mx1=xt_all_exp[,c(6:7)], mx2=xt_all_exp[,9:10],cut_mean=10,small_val=1), #  up phase
cal_wilp2( mx1=xt_all_exp[,11:12], mx2=xt_all_exp[,17:19],cut_mean=10,small_val=1) #  down phase
) 
sigo_drxt<- mapply( function(x, y){
  upg<-get_con_gene( g1=x, g2=y, diff1=dr_diff[,1], diff2=xt_diff[,1], is_dn=F, ind1=5, ind2=3, cor1=drg_cor, cor2=xtg_cor, cut_cor=.4)
  dng<-get_con_gene( g1=x, g2=y, diff1=dr_diff[,2], diff2=xt_diff[,2], is_dn=T, ind1=5, ind2=3, cor1=drg_cor, cor2=xtg_cor, cut_cor=.4)
  res<-list( 
    intersect(upg[[1]],dng[[1]]),
    intersect(upg[[2]],dng[[2]])
  )
  return(res)
}, x=sigo_dr, y=sigo_xt, SIMPLIFY=F)

# plot positively correlated genes in enriched GO terms
plot_dynamic<-function( mx, gene, st_lab, st_col, path, file_name, name, lab_pos=.13, ret_val=F){
plot_mx<-mx[gene,]
plot_mx<- t(apply(plot_mx, 1, function(x){ (x-min(x))/(max(x)-min(x)) }))
if(ret_val) return(plot_mx)
file_name<- paste(path, '/', file_name,'.pdf', sep='')
par(cex=1,las=1,mar=c(4,2.2,1,1),lwd=2,pch=16)
plot( 1:ncol(plot_mx), plot_mx[1,], type='l', xlab='', ylab='relative expression',main=name, frame=F, xaxt='n')
for( i in 2:nrow(plot_mx)) lines( 1:ncol(plot_mx), plot_mx[i,] )
text( 1:ncol(plot_mx), (-par('usr')[4]+par('usr')[3])*lab_pos, label=st_lab, xpd=NA, cex=.8,srt=90, col=st_col )
}
sigo_drxt[['translation']][[1]]<-setdiff(sigo_drxt[['translation']][[1]], 'ENSDARG00000077533')
sigo_drxt[['translation']][[2]]<-setdiff(sigo_drxt[['translation']][[2]], 'ENSXETG00000002620')
sigo_drxt[['mrna splicing']][[1]]<-setdiff(sigo_drxt[['mrna splicing']][[1]], 'ENSDARG00000037968')
sigo_drxt[['mrna splicing']][[2]]<-setdiff(sigo_drxt[['mrna splicing']][[2]], 'ENSXETG00000001951')
names(sigo_drxt)[7]<-'mRNA splicing' # correct the name
for(i in c(1,6,5)){ # for cell cycle, mRNA splicing, translation
  plot_dynamic( mx=dr_all_exp, gene= sigo_drxt[[i]][[1]] , st_lab=dr_st_anno, st_col=rep(col6[c(2:4,6)],c(5,3,7,3)), path='../result/pattern5/', file_name=paste(names(sigo_drxt)[i],'dr' ), name= names(sigo_drxt)[i] ,lab_pos=.2) 
  plot_dynamic( mx=xt_all_exp, gene= sigo_drxt[[i]][[2]] , st_lab=colnames(xt_all_exp), st_col=rep(col6[c(2:4,6)],c(7,3,7,6)), path='../result/pattern5/', file_name=paste( names(sigo_drxt)[i], 'xt' ), name= names(sigo_drxt)[i], lab_pos=.2)
}


# rmarkdown::render('lin28_figs14cd.r')