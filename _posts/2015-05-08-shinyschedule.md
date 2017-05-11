---
title: "A Shiny Creel Scheduler"
categories:
  - rstats
tags:
  - rstats
  - creel

---



A shiny app to generate creel schedules
========================================================

Well once again life has quickly passed me by and its been quite a while since I last posted here.  I have been working 
at finishing up the 2014 creel year with generating reports and writing new R code to interact with our database.  I hope to have some of that 
code for up here in the next few months.  

I teach an R course at the University and we recently spent a couple of months developing shiny apps.  The [online tutorial](http://shiny.rstudio.com/tutorial/) by RStudio is excellent and follows my approach to teaching R by providing numerous opportunities at trying your hand at writing code as you go along.  At the same time, we were covering this I needed
to generate our randomized schedules for our creel clerks for the 2015 season.  I thought this was a perfect opportunity to 
combine the two, and create a shiny app to generate a randomized schedules.  


### Background to the creel schedule
The backbone to a creel survey  is the schedule.  Schedules often follow a  stratified multi-stage probability sampling regime (Malvestuto, 1996) to determine days of interviews.  This often means that there are a number of weekend days and weekday days chosen each month to sample and then these are then randomly selected from those that are available.  During any day sampled, a shift chosen.  For our needs here in Nebraska, we use two periods (a morning shift and an afternoon shift).  The morning shift will go from sunrise (based on sunrise times in Kearney, Nebraska) to 1330 and an afternoon shift that goes from 1330 until sunset (also based on sunset times in Kearney).It is during this time, that the creel clerk will conduct interviews with anglers to estimate the catch rate of the anglers.  In addition,  a creel clerk is also required to conduct an instantaneous (or as close as possible) count of the number of anglers on the waterbody.  The count is used to estimate the number of anglers using the waterbody during that day.  These two values are ultimately multiplied together to estimate the total number of fish caught and harvested.  

### The creel schedule app

![center](/figs/2015-05-08-shinyschedule/ScreenShot.png) 


There are a few options to change parts of the creel schedules using these apps, keeping within the two period, sunrise to sunset framework I mentioned earlier.  

Parameters | Description
-----------|------------
Lake Name  |You can enter a name of the lake here.  This name will be used for the filename
Randomization Seed | This is the numeric seed that will allow for replication of the schedule
Date Range | This sets the beginning and ending date that the schedule should be generated
Number of Weekdays | This is the number of weekdays per month that should be selected
Number of Weekends | This is the number of weekend days per month that should be selected
Counts per shift |	This is the number of instantaneous counts per shift
Add hour | This adds an hour to the end of the shift to conduct interviews.  Counts are still conducted during the standard time frame
Special date type | If "Weekend" is selected, then the special dates listed below will be listed as weekend days.  If "High use" is selected, then the special dates listed below will be included in their own "High use" strata
Special days | This is the number of special dates selected per High Use group.  If Holiday is selected under special day type, then this is disregarded
Date 1-9 | I have provided up to 9 special days per creel season
Group 1-9 | These groupings allow for designation of high use days across months and allows each high use period to be calculated separately (i.e., July 4th holiday is separate from Labor day)

If changes are made in the parameters, there will be no changes made to the schedule to the right until you press Submit.

Download the schedule as a *csv file.  The filename should be in the format "Lake XXXXXXschedule-2015.csv"

There are still a few bugs that I am working on but if you find any please send me a note.  I would be happy to incorporate any bugs or ideas that you might have to better improve the scheduler.  


### How to use
If you want to use the app there are several ways you can run the app:

{% highlight r %}

library(shiny)
runGitHub("creelr", "chrischizinski", subdir = "shiny/schedule", launch.browser =TRUE)

{% endhighlight %}

Some people were having trouble getting the app to run through GitHub, although it works on my computer fine. 

{% highlight r %}

library(shiny)

runUrl("https://github.com/chrischizinski/creelr/archive/master.zip",
       subdir = "shiny/schedule", launch.browser =TRUE)

runUrl("https://github.com/chrischizinski/creelr/archive/master.tar.gz",
       subdir = "shiny/schedule", launch.browser =TRUE)

{% endhighlight %}

Or you can clone the git repository, then use `runApp()`:

{% highlight r %}

# First clone the repository with git. If you have cloned it into
# ~/schedule, first go to that directory, then use runApp().
setwd("~/schedule")
runApp()

{% endhighlight %}

If you are using any of the options above with RStudio, make sure that you have `launch.browser =TRUE` indicated or you will not be able to download the schedule.  


Or and perhaps easiest of all (particularly if you are not using RStudio) you can follow this link:
[chrischizinski.shinyapps.io/scheduleR](https://chrischizinski.shinyapps.io/scheduleR/)

### References
Malvestuto, S.P., 1996. Sampling the recreational fishery. In: Murphy, B.R., Willis,
D.M. (Eds.), Fisheries Techniques. (second ed.). American Fisheries Society,
Bethesda, MD, pp. 591–623.  
