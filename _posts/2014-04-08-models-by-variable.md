---
title: "Models by a factor"
categories:
  - rstats
tags:
  - rstats
  - model building
---


Recently, a friend asked a question on ways to run a single model by a grouping variable in a dataset (similar to the BY statement in SAS for those familiar with SAS).  This was a list of the multiple different ways
that were suggested.  


I will use the [baseball dataset](http://www.inside-r.org/packages/cran/plyr/docs/baseball) in the *plyr* package to go through the different approaches.  


### Load and display the data

{% highlight r %}
library(plyr)  #load the plyr package
data(baseball)  #load the baseball dataset that comes with plyr
head(baseball)  # display the first six lines of the data.frame
{% endhighlight %}



{% highlight text %}
##            id year stint team lg  g  ab  r  h X2b X3b hr rbi sb cs bb so
## 4   ansonca01 1871     1  RC1    25 120 29 39  11   3  0  16  6  2  2  1
## 44  forceda01 1871     1  WS3    32 162 45 45   9   4  0  29  8  0  4  0
## 68  mathebo01 1871     1  FW1    19  89 15 24   3   1  0  10  2  1  2  0
## 99  startjo01 1871     1  NY2    33 161 35 58   5   1  1  34  4  2  3  0
## 102 suttoez01 1871     1  CL1    29 128 35 45   3   7  3  23  3  1  1  0
## 106 whitede01 1871     1  CL1    29 146 40 47   6   5  1  21  2  2  4  1
##     ibb hbp sh sf gidp
## 4    NA  NA NA NA   NA
## 44   NA  NA NA NA   NA
## 68   NA  NA NA NA   NA
## 99   NA  NA NA NA   NA
## 102  NA  NA NA NA   NA
## 106  NA  NA NA NA   NA
{% endhighlight %}


To look at the year-team combinations in the data, use the ddply function

{% highlight r %}
baseball$team <- as.character(baseball$team)  #convert team from a factor to a character

# For the purpose of this excercise we will reduce the dataset to just a few
# teams
baseball.red <- baseball[baseball$team %in% c("BOS", "CHN", "CIN"), ]

# Use ddply again to create a variable called c_year, which is the number of
# years since the first year
baseball.red <- ddply(baseball.red, .(id), transform, c_year = year - min(year))
{% endhighlight %}

So the basic idea for the process I am going to use, is that I am going to use a Poisson regression using the *glm* function in R to look at the hits as a function of year since the first year of data was included in the dataset.  Is the model 100% valid?  No but for this the actual model is not important.  

Further, the approaches I am describing below, are runnign the same model with same dependent and independent variables across different subsets of data.  If you were interested in running different subsets of independent variables there are also many different approaches that could be considered, but I will not go into that at this time.  

### 1. Subsetting and running each model seperate
The basic process is to run each model seperately by providing a different subset of the data.  Not very difficult to do, but if you had a bunch of models to run, it can very quickly add up.  The nice thing about this process though is that you have very clear model outputs (i.e., a specific output for BOS, CHN, and CIN).  

{% highlight r %}
mod.BOS <- glm(h ~ c_year, data = baseball.red[baseball.red$team == "BOS", ], 
    family = "poisson")  # run the model using only team BOS
summary(mod.BOS)  #  Display the model summary
{% endhighlight %}



{% highlight text %}
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     "BOS", ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -14.29  -10.16   -5.28    6.82   17.97  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 3.943280   0.005922   665.9   <2e-16 ***
## c_year      0.034136   0.000884    38.6   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 72809  on 900  degrees of freedom
## Residual deviance: 71420  on 899  degrees of freedom
## AIC: 75179
## 
## Number of Fisher Scoring iterations: 6
{% endhighlight %}



{% highlight r %}

mod.CHN <- glm(h ~ c_year, data = baseball.red[baseball.red$team == "CHN", ], 
    family = "poisson")
summary(mod.CHN)
{% endhighlight %}



{% highlight text %}
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     "CHN", ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -13.94   -9.17   -2.72    6.21   16.82  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 4.071993   0.005087   800.5   <2e-16 ***
## c_year      0.033453   0.000737    45.4   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 80354  on 1178  degrees of freedom
## Residual deviance: 78403  on 1177  degrees of freedom
## AIC: 84317
## 
## Number of Fisher Scoring iterations: 5
{% endhighlight %}



{% highlight r %}

mod.CIN <- glm(h ~ c_year, data = baseball.red[baseball.red$team == "CIN", ], 
    family = "poisson")
summary(mod.CIN)
{% endhighlight %}



{% highlight text %}
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     "CIN", ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -12.40   -9.48   -2.03    6.35   14.83  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept)  4.21200    0.00528  797.57  < 2e-16 ***
## c_year       0.00589    0.00082    7.19  6.6e-13 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 70036  on 1029  degrees of freedom
## Residual deviance: 69984  on 1028  degrees of freedom
## AIC: 75122
## 
## Number of Fisher Scoring iterations: 5
{% endhighlight %}


### 2. Subsetting and running through a loop
This process first identifies all the uniqe teams listed in the dataset and then will loop through those teams and store the output in a list.  The summary   for all the models can be provided by running lapply on that list or running summary on an extracted element of the list.  Problem with this method is just the inherent complication of using lists in R and running loops can take quite a long time especially on large datasets.  If it is speed you are after there are quicker options.  

{% highlight r %}
uniq.teams <- unique(baseball.red$team)  # find all the unique teams in the dataset
model.out <- list()  # create a list to store each model

for (i in 1:length(uniq.teams)) {
    model.out[[paste(uniq.teams[i])]] <- glm(h ~ c_year, data = baseball.red[baseball.red$team == 
        paste(uniq.teams[i]), ], family = "poisson")
}

lapply(model.out, summary)  # look at all the model outputs, this could be used with outputs on 3 and 5 as well.  
{% endhighlight %}



{% highlight text %}
## $CHN
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     paste(uniq.teams[i]), ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -13.94   -9.17   -2.72    6.21   16.82  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 4.071993   0.005087   800.5   <2e-16 ***
## c_year      0.033453   0.000737    45.4   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 80354  on 1178  degrees of freedom
## Residual deviance: 78403  on 1177  degrees of freedom
## AIC: 84317
## 
## Number of Fisher Scoring iterations: 5
## 
## 
## $CIN
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     paste(uniq.teams[i]), ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -12.40   -9.48   -2.03    6.35   14.83  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept)  4.21200    0.00528  797.57  < 2e-16 ***
## c_year       0.00589    0.00082    7.19  6.6e-13 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 70036  on 1029  degrees of freedom
## Residual deviance: 69984  on 1028  degrees of freedom
## AIC: 75122
## 
## Number of Fisher Scoring iterations: 5
## 
## 
## $BOS
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     paste(uniq.teams[i]), ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -14.29  -10.16   -5.28    6.82   17.97  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 3.943280   0.005922   665.9   <2e-16 ***
## c_year      0.034136   0.000884    38.6   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 72809  on 900  degrees of freedom
## Residual deviance: 71420  on 899  degrees of freedom
## AIC: 75179
## 
## Number of Fisher Scoring iterations: 6
{% endhighlight %}



{% highlight r %}
summary(model.out[["CIN"]])  # or look at a specific model
{% endhighlight %}



{% highlight text %}
## 
## Call:
## glm(formula = h ~ c_year, family = "poisson", data = baseball.red[baseball.red$team == 
##     paste(uniq.teams[i]), ])
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -12.40   -9.48   -2.03    6.35   14.83  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept)  4.21200    0.00528  797.57  < 2e-16 ***
## c_year       0.00589    0.00082    7.19  6.6e-13 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 70036  on 1029  degrees of freedom
## Residual deviance: 69984  on 1028  degrees of freedom
## AIC: 75122
## 
## Number of Fisher Scoring iterations: 5
{% endhighlight %}



{% highlight r %}

{% endhighlight %}


### 3. Using *split* and *lapply*
This process splits the dataset into seperate lists by a variable and then uses *lapply* to run the glm model across those different datasets.  

{% highlight r %}
datasets <- split(baseball.red, baseball.red$team)  # splits the dataset into a list by team
str(datasets)  # look at the structure of the dataset
{% endhighlight %}



{% highlight text %}
## List of 3
##  $ BOS:'data.frame':	901 obs. of  23 variables:
##   ..$ id    : chr [1:901] "adairje01" "adairje01" "aguilri01" "altroni01" ...
##   ..$ year  : int [1:901] 1967 1968 1995 1902 1903 1988 1990 1971 1972 1973 ...
##   ..$ stint : int [1:901] 2 1 2 1 1 1 2 1 1 1 ...
##   ..$ team  : chr [1:901] "BOS" "BOS" "BOS" "BOS" ...
##   ..$ lg    : chr [1:901] "AL" "AL" "AL" "AL" ...
##   ..$ g     : int [1:901] 89 74 30 3 1 41 15 125 110 132 ...
##   ..$ ab    : int [1:901] 316 208 0 8 3 148 0 491 436 499 ...
##   ..$ r     : int [1:901] 41 18 0 0 0 14 0 56 47 56 ...
##   ..$ h     : int [1:901] 92 45 0 0 2 34 0 114 112 135 ...
##   ..$ X2b   : int [1:901] 13 1 0 0 0 5 0 23 26 17 ...
##   ..$ X3b   : int [1:901] 1 0 0 0 0 3 0 0 3 1 ...
##   ..$ hr    : int [1:901] 3 2 0 0 0 0 0 4 3 0 ...
##   ..$ rbi   : int [1:901] 26 12 0 0 0 12 0 45 39 49 ...
##   ..$ sb    : int [1:901] 1 0 0 0 0 4 0 6 3 13 ...
##   ..$ cs    : int [1:901] 4 0 0 NA NA 2 0 4 3 1 ...
##   ..$ bb    : int [1:901] 13 9 0 0 1 15 0 35 26 43 ...
##   ..$ so    : int [1:901] 35 28 0 NA NA 35 0 43 28 33 ...
##   ..$ ibb   : int [1:901] 0 2 0 NA NA 0 0 0 0 1 ...
##   ..$ hbp   : int [1:901] 2 1 0 0 0 4 0 2 2 0 ...
##   ..$ sh    : int [1:901] 4 6 0 0 0 4 0 9 5 12 ...
##   ..$ sf    : int [1:901] 2 0 0 NA NA 1 0 4 5 7 ...
##   ..$ gidp  : int [1:901] 10 10 0 NA NA 2 0 7 8 12 ...
##   ..$ c_year: int [1:901] 0 1 0 0 1 0 0 0 1 2 ...
##  $ CHN:'data.frame':	1179 obs. of  23 variables:
##   ..$ id    : chr [1:1179] "abernte02" "abernte02" "abernte02" "abernte02" ...
##   ..$ year  : int [1:1179] 1965 1966 1969 1970 1957 1958 1959 1999 2000 1969 ...
##   ..$ stint : int [1:1179] 1 1 1 1 1 1 1 2 1 1 ...
##   ..$ team  : chr [1:1179] "CHN" "CHN" "CHN" "CHN" ...
##   ..$ lg    : chr [1:1179] "NL" "NL" "NL" "NL" ...
##   ..$ g     : int [1:1179] 84 20 56 11 60 62 3 41 50 41 ...
##   ..$ ab    : int [1:1179] 18 4 8 0 187 96 2 1 0 5 ...
##   ..$ r     : int [1:1179] 1 0 1 0 21 14 0 0 0 2 ...
##   ..$ h     : int [1:1179] 3 0 2 0 47 27 0 0 0 2 ...
##   ..$ X2b   : int [1:1179] 0 0 1 0 10 4 0 0 0 0 ...
##   ..$ X3b   : int [1:1179] 0 0 0 0 2 4 0 0 0 0 ...
##   ..$ hr    : int [1:1179] 0 0 0 0 1 0 0 0 0 0 ...
##   ..$ rbi   : int [1:1179] 2 0 1 0 10 4 0 0 0 0 ...
##   ..$ sb    : int [1:1179] 0 0 0 0 0 2 0 0 0 0 ...
##   ..$ cs    : int [1:1179] 0 0 0 0 3 0 0 0 0 0 ...
##   ..$ bb    : int [1:1179] 0 0 0 0 17 6 0 0 0 0 ...
##   ..$ so    : int [1:1179] 7 2 2 0 28 15 1 0 0 1 ...
##   ..$ ibb   : int [1:1179] 0 0 0 0 0 0 0 0 0 0 ...
##   ..$ hbp   : int [1:1179] 1 0 0 0 2 0 0 0 0 0 ...
##   ..$ sh    : int [1:1179] 3 0 0 0 5 3 0 0 0 0 ...
##   ..$ sf    : int [1:1179] 0 0 0 0 0 0 0 0 0 0 ...
##   ..$ gidp  : int [1:1179] 0 0 0 0 2 2 0 0 0 0 ...
##   ..$ c_year: int [1:1179] 0 1 4 5 11 12 13 4 5 0 ...
##  $ CIN:'data.frame':	1030 obs. of  23 variables:
##   ..$ id    : chr [1:1030] "abernte02" "abernte02" "adamsbo03" "adamsbo03" ...
##   ..$ year  : int [1:1030] 1967 1968 1946 1947 1948 1949 1950 1951 1952 1953 ...
##   ..$ stint : int [1:1030] 1 1 1 1 1 1 1 1 1 1 ...
##   ..$ team  : chr [1:1030] "CIN" "CIN" "CIN" "CIN" ...
##   ..$ lg    : chr [1:1030] "NL" "NL" "NL" "NL" ...
##   ..$ g     : int [1:1030] 70 78 94 81 87 107 115 125 154 150 ...
##   ..$ ab    : int [1:1030] 17 17 311 217 262 277 348 403 637 607 ...
##   ..$ r     : int [1:1030] 0 2 35 39 33 32 57 57 85 99 ...
##   ..$ h     : int [1:1030] 1 0 76 59 78 70 98 107 180 167 ...
##   ..$ X2b   : int [1:1030] 0 0 13 11 20 16 21 12 25 14 ...
##   ..$ X3b   : int [1:1030] 0 0 3 2 3 2 8 5 4 6 ...
##   ..$ hr    : int [1:1030] 0 0 4 4 1 0 3 5 6 8 ...
##   ..$ rbi   : int [1:1030] 2 0 24 20 21 25 25 24 48 49 ...
##   ..$ sb    : int [1:1030] 0 0 16 9 6 4 7 4 11 3 ...
##   ..$ cs    : int [1:1030] 0 0 NA NA NA NA NA 10 9 2 ...
##   ..$ bb    : int [1:1030] 0 3 18 25 25 26 43 43 49 58 ...
##   ..$ so    : int [1:1030] 10 12 32 23 23 36 29 40 67 67 ...
##   ..$ ibb   : int [1:1030] 0 0 NA NA NA NA NA NA NA NA ...
##   ..$ hbp   : int [1:1030] 0 0 3 4 1 0 0 1 0 0 ...
##   ..$ sh    : int [1:1030] 0 0 14 7 7 5 3 3 8 12 ...
##   ..$ sf    : int [1:1030] 0 0 NA NA NA NA NA NA NA NA ...
##   ..$ gidp  : int [1:1030] 1 0 7 2 5 6 2 6 15 7 ...
##   ..$ c_year: int [1:1030] 2 3 0 1 2 3 4 5 6 7 ...
{% endhighlight %}



{% highlight r %}
model.out <- lapply(datasets, function(x) glm(h ~ c_year, family = "poisson", 
    data = x))  # apply the glm function across the dataset list

# lapply(model.out,summary), # Not run because output is the same as above
{% endhighlight %}


### 4. Using *by*
This process is similar to the one directly above but will do it in a single line of code.  Essentially what *by* does is the "data frame is split by row into data frames subsetted by the values of one or more factors, and function FUN is applied to each subset in turn"


{% highlight r %}
model.out <- by(data = baseball.red, baseball.red$team, function(x) glm(h ~ 
    c_year, family = "poisson", data = x))
model.out
{% endhighlight %}



{% highlight text %}
## baseball.red$team: BOS
## 
## Call:  glm(formula = h ~ c_year, family = "poisson", data = x)
## 
## Coefficients:
## (Intercept)       c_year  
##      3.9433       0.0341  
## 
## Degrees of Freedom: 900 Total (i.e. Null);  899 Residual
## Null Deviance:	    72800 
## Residual Deviance: 71400 	AIC: 75200
## -------------------------------------------------------- 
## baseball.red$team: CHN
## 
## Call:  glm(formula = h ~ c_year, family = "poisson", data = x)
## 
## Coefficients:
## (Intercept)       c_year  
##      4.0720       0.0335  
## 
## Degrees of Freedom: 1178 Total (i.e. Null);  1177 Residual
## Null Deviance:	    80400 
## Residual Deviance: 78400 	AIC: 84300
## -------------------------------------------------------- 
## baseball.red$team: CIN
## 
## Call:  glm(formula = h ~ c_year, family = "poisson", data = x)
## 
## Coefficients:
## (Intercept)       c_year  
##     4.21200      0.00589  
## 
## Degrees of Freedom: 1029 Total (i.e. Null);  1028 Residual
## Null Deviance:	    70000 
## Residual Deviance: 70000 	AIC: 75100
{% endhighlight %}


### 5. Using *dlply* 
One package I use in alot of my analyses is the  [plyr package](http://cran.r-project.org/web/packages/plyr/index.html) created by [Hadley Wickham](http://had.co.nz/) (author of **ggplot2**, another package I use daily).  This packages make subsetting and applying functions incredibly easy and are relatively fast.  


{% highlight r %}
library(plyr)
model.out <- dlply(baseball.red, .(team), glm, formula = h ~ c_year, family = poisson)  #dlply takes the data as a dataframe and returns the output as a list
llply(model.out, summary)  #uses llply (list input - list output) to display the summary (instead of lapply, but lapply works as well)
{% endhighlight %}



{% highlight text %}
## $BOS
## 
## Call:
## .fun(formula = ..1, family = ..2, data = piece)
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -14.29  -10.16   -5.28    6.82   17.97  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 3.943280   0.005922   665.9   <2e-16 ***
## c_year      0.034136   0.000884    38.6   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 72809  on 900  degrees of freedom
## Residual deviance: 71420  on 899  degrees of freedom
## AIC: 75179
## 
## Number of Fisher Scoring iterations: 6
## 
## 
## $CHN
## 
## Call:
## .fun(formula = ..1, family = ..2, data = piece)
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -13.94   -9.17   -2.72    6.21   16.82  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept) 4.071993   0.005087   800.5   <2e-16 ***
## c_year      0.033453   0.000737    45.4   <2e-16 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 80354  on 1178  degrees of freedom
## Residual deviance: 78403  on 1177  degrees of freedom
## AIC: 84317
## 
## Number of Fisher Scoring iterations: 5
## 
## 
## $CIN
## 
## Call:
## .fun(formula = ..1, family = ..2, data = piece)
## 
## Deviance Residuals: 
##    Min      1Q  Median      3Q     Max  
## -12.40   -9.48   -2.03    6.35   14.83  
## 
## Coefficients:
##             Estimate Std. Error z value Pr(>|z|)    
## (Intercept)  4.21200    0.00528  797.57  < 2e-16 ***
## c_year       0.00589    0.00082    7.19  6.6e-13 ***
## ---
## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
## 
## (Dispersion parameter for poisson family taken to be 1)
## 
##     Null deviance: 70036  on 1029  degrees of freedom
## Residual deviance: 69984  on 1028  degrees of freedom
## AIC: 75122
## 
## Number of Fisher Scoring iterations: 5
{% endhighlight %}


As in a lot of things in R, there are many different approaches to the same problem. I personally tend to shy away from the use of the *lapply*, *mapply*, and *tapply* approaches but use the **plyr** package in most analysis.  
