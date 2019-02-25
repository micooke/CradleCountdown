using Toybox.Time as Time;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.ActivityMonitor as ActMon;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Application as App;
using Toybox.Math as Math;
/*
char id=35 x=180    y=15     width=14    height=14    xoffset=0     yoffset=4     xadvance=14    page=0  chnl=15
char id=36 x=165     y=15     width=15    height=14    xoffset=0     yoffset=4     xadvance=15    page=0  chnl=15
*/
class CradleCountdownView extends Ui.WatchFace {
	hidden var inLowPower, doPartialUpdate = false, hasPartialUpdate = false;
	
	hidden var ShowBattery, ShowNotifications, CoreSelection;
	hidden var smallDateFont, dateFont, timeFont, timeCheckerFont;
	
	hidden const ordinalIndicator = ["TH","ST","ND","RD","TH","TH","TH","TH","TH","TH"];
	hidden const engDay = ["","sun","mon","tue","wed","thu","fri","sat"];
	hidden const engMonth = ["","jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"];
	hidden const overstepGap = 2, overstepWidth = 3, mediumDateOffset = 5, halfMediumDateOffset = 3, stepArcWidth = 4;
			
	hidden const dateFontHeight = 33;//*1.25;
	hidden const timeFontHeight = 59*1.05;
	//                           [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	hidden const timeFontWidth = [51,28,45,42,47,44,48,43,50,48]; // get this from the relevant fnt file (column width)
	hidden const smallDateFontHeight = 16;
	hidden const halfSmallDateFontHeight = 8;
	// get this from the relevant fnt file (column xadvance)
	hidden const smallDateWidth = {" "=>6,"%"=>16,"0"=>11,"1"=>6,"2"=>10,"3"=>9,"4"=>10,"5"=>10,"6"=>10,"7"=>9,"8"=>11,"9"=>10,
					"A"=>11,"B"=>11,"C"=>9,"D"=>11,"E"=>10,"F"=>9,"G"=>11,"H"=>11,"I"=>6,"J"=>9,"K"=>11,"L"=>9,"M"=>14,
					"N"=>11,"O"=>11,"P"=>11,"Q"=>11,"R"=>11,"S"=>10,"T"=>10,"U"=>11,"V"=>11,"W"=>14,"X"=>11,"Y"=>11,"Z"=>9,
					"#"=>15,"$"=>16};
	
	// settings
	hidden var is24Hour;
	hidden const backgroundColour = Gfx.COLOR_BLACK, MinuteColour = Gfx.COLOR_WHITE;
	hidden const DateColour = Gfx.COLOR_LT_GRAY, OverActiveColour = Gfx.COLOR_WHITE;
	hidden var ActiveColour = Gfx.COLOR_BLUE, HourColour = Gfx.COLOR_BLUE; // defaults for watch settings
	hidden var TimeCheckerplateStyle = -1, DateCheckerplateStyle = -1;
	
	// screen and font dimensions
	hidden var timeVerticalCentre, dateVerticalCentre, smallDateVerticalCentre;
  	hidden var halfScreenWidth, halfScreenHeight;
  	
  	// UTC time of 1st Mar @ 3 AM in Florida, USA
  	hidden var release_title = "Underlord";
	hidden var release_date_settings = {
	    :year   => 2019,
	    :month  => 3,
	    :day    => 1,
	    :hour   => 8, // UTC offset, in this case for CST
	    :minute   => 00,
	    :second   => 0
	};
	
	hidden var release_date;
	
	function initialize()
	{
		WatchFace.initialize();
		updateSettings();
		
		timeFont = Ui.loadResource(Rez.Fonts.Digitalt);
		smallDateFont = Ui.loadResource(Rez.Fonts.DigitaltSmall);
		timeCheckerFont = Ui.loadResource(Rez.Fonts.DigitaltChecker2);
		dateFont = Ui.loadResource(Rez.Fonts.DigitaltMedium);
		
		release_date = Time.Gregorian.moment(release_date_settings);
		
		hasPartialUpdate = ( Toybox.WatchUi.WatchFace has :onPartialUpdate );
        doPartialUpdate = hasPartialUpdate; 
	}

	function onLayout(dc) {
		getScreenDimensions(dc);
		updateSettings();
	}
	
	function getScreenDimensions(dc)
	{
  		halfScreenWidth = (dc.getWidth() / 2).toNumber();
   		halfScreenHeight = (dc.getHeight() / 2).toNumber();
   		
   		timeVerticalCentre = halfScreenHeight - 0.5*timeFontHeight;
		dateVerticalCentre = halfScreenHeight - 0.5*dateFontHeight;
  		smallDateVerticalCentre = halfScreenHeight - 0.5*smallDateFontHeight;
	}
	
	function updateSettings() {
		// settings menu
		ShowBattery = Application.getApp().getProperty("ShowBattery");
		ShowNotifications = Application.getApp().getProperty("ShowNotifications");
		
		CoreSelection = Application.getApp().getProperty("CoreSelection");
		
		if (CoreSelection == 0) // Pure Core
		{
			HourColour = Gfx.COLOR_BLUE;
		}
		else // Blackflame Core
		{
			HourColour = Gfx.COLOR_RED;
		}
		
		ActiveColour = HourColour;
		
		// watch settings
		var deviceSettings = System.getDeviceSettings();
		is24Hour = deviceSettings.is24Hour;
	}
	
	function onSettingsChanged() { // triggered by settings change in GCM
		updateSettings();        
    	WatchUi.requestUpdate();   // update the view to reflect changes
	}
	
	// The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    	inLowPower=false;
    	if(doPartialUpdate == false) {WatchUi.requestUpdate();} 
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    	inLowPower=true;
    	if(doPartialUpdate == false) {WatchUi.requestUpdate();}
    }
    
    function onPartialUpdate(dc) {
    	drawTimeToGo(dc, true);
    }

	function onUpdate(dc) {
		if(hasPartialUpdate) {dc.clearClip();}
		
		drawWatchface(dc);
	}
	
	function drawWatchface(dc)
	{
		// setup the watch face / draw the background
	    dc.clearClip();
		dc.setColor(backgroundColour, backgroundColour);
		dc.clear();

		// draw the time and date
		drawTime(dc);
		drawDate(dc);
		
		// draw the time to go
		drawTimeToGo(dc, false);
		
		// draw the step count
		drawStepCount(dc);
		
		// draw the battery percent
    	drawBatteryLevel(dc);

	    // draw the notification count
		drawNotificationCount(dc);
	}
	
	function drawDate(dc)
    {
		// get the date
		var clockDate = Calendar.info(Time.now(), Time.FORMAT_SHORT); // FORMAT_SHORT returns digits

		//clockDate.day_of_week = 7; clockDate.day = 2; clockDate.month = 2; // DEBUG

		// get english only month and day
		var day_of_week = engDay[clockDate.day_of_week];
		var day = clockDate.day;
		var month = engMonth[clockDate.month];

		var dateStringSplit = [ day_of_week.toUpper(),
								day.toString() + ordinalIndicator[day % 10],
								month.toUpper()];
								
		if ((day > 10) && (day < 14))
        {
        	dateStringSplit[1] = day.toString() + "TH";
        } 
        
		dc.setColor(DateColour, Gfx.COLOR_TRANSPARENT);
		var dateVerticalPos = [timeVerticalCentre - 0.5*timeFontHeight,
								dateVerticalCentre,
								timeVerticalCentre + timeFontHeight - 4];
    	dc.drawText(halfScreenWidth + mediumDateOffset, dateVerticalPos[0], dateFont, dateStringSplit[0], Gfx.TEXT_JUSTIFY_LEFT);
    	dc.drawText(halfScreenWidth + mediumDateOffset, dateVerticalPos[1], dateFont, dateStringSplit[1], Gfx.TEXT_JUSTIFY_LEFT);
    	dc.drawText(halfScreenWidth + mediumDateOffset, dateVerticalPos[2], dateFont, dateStringSplit[2], Gfx.TEXT_JUSTIFY_LEFT);
	}
	
	function drawTime(dc)
    {
        // get local time
		var clockTime = Sys.getClockTime();
		//clockTime.hour = inc; inc++; // DEBUG
		//clockTime.min = clockTime.hour;// DEBUG
		// the hour is returned in 24-hr format
		//localHour = localHour.format("%02d");

		if (clockTime.hour == 24) // Not sure if this is needed?
        {
            clockTime.hour = 0;
        }
        
		if ((!is24Hour) && (clockTime.hour > 12))
        {
            clockTime.hour -= 12;
        }
		//clockTime.hour = 6; // DEBUG
		
        // setup the time
		var hourLabel = clockTime.hour.format("%02d");
		var minuteLabel = clockTime.min.format("%02d");
        
        dc.setColor(HourColour, Gfx.COLOR_TRANSPARENT);
		if (clockTime.hour < 10)
		{
			dc.drawText(halfScreenWidth - timeFontWidth[clockTime.hour], timeVerticalCentre - 0.5*timeFontHeight, timeCheckerFont, "0", Gfx.TEXT_JUSTIFY_RIGHT);
			dc.drawText(halfScreenWidth, timeVerticalCentre - 0.5*timeFontHeight, timeFont, (clockTime.hour).toString(), Gfx.TEXT_JUSTIFY_RIGHT);
		}
		else
		{
			dc.drawText(halfScreenWidth, timeVerticalCentre - 0.5*timeFontHeight, timeFont, hourLabel, Gfx.TEXT_JUSTIFY_RIGHT);	
		}
		dc.setColor(MinuteColour, Gfx.COLOR_TRANSPARENT);
		dc.drawText(halfScreenWidth, timeVerticalCentre + 0.5*timeFontHeight, timeFont, minuteLabel, Gfx.TEXT_JUSTIFY_RIGHT);
    }
	
	function drawTimeToGo(dc, doPartial)
    {
    	var colour = MinuteColour;
    	
   		var seconds = release_date.compare(Time.now());
		
        if (seconds > 0)
        {
        	var days = (seconds / Time.Gregorian.SECONDS_PER_DAY).toNumber(); seconds -= (days * Time.Gregorian.SECONDS_PER_DAY);
        	var hours = (seconds / Time.Gregorian.SECONDS_PER_HOUR).toNumber(); seconds -= (hours * Time.Gregorian.SECONDS_PER_HOUR);
        	var minutes = (seconds / Time.Gregorian.SECONDS_PER_MINUTE).toNumber(); seconds -= (minutes * Time.Gregorian.SECONDS_PER_MINUTE);
        
	    	var SecOffset = halfScreenWidth+3*smallDateFontHeight;
	        
	        // day | hour:minute:second stacked vertically
	    	var ttgTimeString = Lang.format("$1$:$2$:$3$", [hours.format("%02d"), minutes.format("%02d"), seconds.format("%02d")]);
	    	
	    	if (!doPartial)
	    	{
	    		var dayString = days.toString() + " DAY";
	    		dayString += ((days>1) | (days == 0))?"S ":" ";
	    		
	    		// clear the previous partial update
	    		dc.setClip(SecOffset, halfScreenHeight + timeFontHeight+4, 1.5*smallDateFontHeight, smallDateFontHeight-2);
	        	dc.setColor(backgroundColour, backgroundColour);
				dc.clear();
				dc.clearClip();
				dc.setColor(colour, Gfx.COLOR_TRANSPARENT);
				
				// draw the time to go
				dc.drawText(halfScreenWidth, halfScreenHeight + timeFontHeight, smallDateFont, ttgTimeString, Gfx.TEXT_JUSTIFY_LEFT);
				dc.drawText(halfScreenWidth, halfScreenHeight + timeFontHeight, smallDateFont, dayString, Gfx.TEXT_JUSTIFY_RIGHT);
				// draw the release title
	    		dc.drawText(halfScreenWidth, halfScreenHeight - timeFontHeight - smallDateFontHeight, smallDateFont, release_title.toUpper(), Gfx.TEXT_JUSTIFY_CENTER);
	    	}
	    	else
	    	{
				dc.setClip(SecOffset, halfScreenHeight + timeFontHeight+4, 1.6*smallDateFontHeight, smallDateFontHeight-2);
	        	dc.setColor(backgroundColour, backgroundColour);
				dc.clear();
				dc.setColor(colour, Gfx.COLOR_TRANSPARENT);
				dc.drawText(halfScreenWidth, halfScreenHeight + timeFontHeight, smallDateFont, ttgTimeString, Gfx.TEXT_JUSTIFY_LEFT);
				dc.clearClip();
			}
		}
    }
	
	function drawArc(dc, degreeStart, degreeEnd, stepArcWidth, arcColour)
	{
		dc.setColor(arcColour, Gfx.COLOR_TRANSPARENT);
		if (degreeEnd > 90)
        {
        	if ((degreeStart > 90) == false)
        	{
         		dc.drawArc(halfScreenWidth, halfScreenHeight, halfScreenWidth - stepArcWidth, Gfx.ARC_CLOCKWISE, 90 - degreeStart, 0);
         		dc.drawArc(halfScreenWidth, halfScreenHeight, halfScreenWidth - stepArcWidth, Gfx.ARC_CLOCKWISE, 0, 360 - (degreeEnd - 90));
         	}
         	else
         	{
         		dc.drawArc(halfScreenWidth, halfScreenHeight, halfScreenWidth - stepArcWidth, Gfx.ARC_CLOCKWISE, 360 - (degreeStart - 90), 360 - (degreeEnd - 90));
         	}
		}
        else
        {
        	dc.drawArc(halfScreenWidth, halfScreenHeight, halfScreenWidth - stepArcWidth, Gfx.ARC_CLOCKWISE, 90 - degreeStart, 90 - degreeEnd);         	
        }
	}
	
	function drawOverStepPos(dc, stepPercent, arcWidth, MinuteColour)
    {
	     dc.setColor(MinuteColour, Gfx.COLOR_TRANSPARENT);
         dc.setPenWidth(arcWidth);
         
         var overStepCount = stepPercent.toNumber();
         var arcPercent = stepPercent - overStepCount.toFloat();
         
         var arcSwathDeg = overstepWidth;
         var arcGapDeg = overstepGap;
     	 
     	 for (var index = 0; index < overStepCount; index++)
     	 {
     	 	var degreeEnd = 360 * arcPercent - (arcGapDeg + arcSwathDeg)*index;
     	 	var degreeStart = degreeEnd - arcSwathDeg;
     	 
     	 	drawArc(dc, degreeStart, degreeEnd, arcWidth, MinuteColour);	
     	 }
     	 
    }
    
    function drawStepCount(dc)
    {
		// get the current step count
      	var ActInfo = ActMon.getInfo();
		var stepCount = ActInfo.steps;
		var stepGoal = ActInfo.stepGoal;
		var stepPercent = (stepCount == 0.0)?0.0:(stepCount.toFloat() / stepGoal);
		//stepPercent = 2.65; // DEBUG
                
		// meta parameters
		var overStepCount = stepPercent.toNumber();
	   	var fillPercent = stepPercent - overStepCount.toFloat();
    
    	if (stepPercent > 0.0)
		 {
	         dc.setColor(HourColour, Gfx.COLOR_TRANSPARENT);
	         dc.setPenWidth(stepArcWidth);
	         var degreeStart = 0;
	         
	         var degreeEnd = degreeStart;
	         if (stepPercent > 1.0)
	         {
	         	degreeEnd += (360 - degreeStart);
	         }
	         else
	         {
	         	degreeEnd += (360 - degreeStart)*stepPercent;
	         }
         	
         	 drawArc(dc, degreeStart, degreeEnd, stepArcWidth, HourColour);
         	 	         
	         if (stepPercent > 1.0)
	         {
	         	drawOverStepPos(dc, stepPercent, stepArcWidth, MinuteColour);
	         }
        }
    }
    
    // draw the notification count
    function drawNotificationCount(dc)
    {
    	if (ShowNotifications)
	    {
	    	var deviceSettings = System.getDeviceSettings();
		    var notificationCount = deviceSettings.notificationCount;
			//notificationCount = 10; // DEBUG
			drawNotificationCountAtHeight(dc, notificationCount, 6);
		}
	}
    
    function drawNotificationCountAtHeight(dc, notificationCount, height)
    {
		if (notificationCount > 0)
		{
			dc.setColor(DateColour, Gfx.COLOR_TRANSPARENT);
			dc.drawText(halfScreenWidth - 1, height, smallDateFont, notificationCount.format("%d")+"#", Gfx.TEXT_JUSTIFY_CENTER);
		}
    }
    
    function drawBatteryLevel(dc)
    {
    	if (ShowBattery)
    	{
    		var batteryLevel = Sys.getSystemStats().battery;
    		var batteryLevelString = batteryLevel.format("%d") + "%";
			dc.setColor(DateColour, Gfx.COLOR_TRANSPARENT);
    		dc.drawText(halfScreenWidth, 2*halfScreenHeight - 1.6*smallDateFontHeight, smallDateFont, batteryLevelString, Gfx.TEXT_JUSTIFY_CENTER);
		}
	}
    
    function drawTextArray(dc, in_string, x_0, y_0, x_offsets, y_offsets)
    {
    	for (var c=0; c < x_offsets.size(); ++c)
    	{
    		dc.drawText(x_0 + x_offsets[c], y_0 + y_offsets[c], smallDateFont, in_string.substring(c,c+1), Gfx.TEXT_JUSTIFY_CENTER);
		}
    }
    
    function getY_onArc(x_offsets, radius)
    {
    	var y_offsets = new[x_offsets.size()];
    	var radius_squared = Math.pow(radius,2);
    	for (var c=0; c < x_offsets.size(); ++c)
    	{
    		y_offsets[c] = radius - Math.sqrt(radius_squared - Math.pow(x_offsets[c],2));
    	}
    	return y_offsets;
    }

	function getSmallDateOffsets(in_string)
	{
		var in_length = in_string.length();
		var out_lengths = new[in_length];
		
		// determine cumulative length
		out_lengths[0] = smallDateWidth.get(in_string.substring(0,1));
		for (var c=1; c < in_length; ++c)
		{
			out_lengths[c] = out_lengths[c-1] + smallDateWidth.get(in_string.substring(c,c+1));
		}
		
		// re-centre the lengths
		var halfActualLength = Math.round(out_lengths[in_length - 1]/2);
		if ((in_length % 2) == 1) // odd length
		{
			// it looks more natural to put the middle char in the middle
			halfActualLength = out_lengths[(in_length/2).toNumber()];
		}
		
		out_lengths = addScalar(out_lengths, -halfActualLength);
		
		return out_lengths;
	}

    function endPad(in_string, out_length, pad_value)
    {
    	var out_string = in_string;
    	for (var p=in_string.length(); p < out_length; ++p)
    	{
    		out_string += pad_value;
    	}
    	
    	return out_string;
    }
    
    function max(in_array)
    {
    	var maximum = in_array[0]; 
    	for (var i=0; i < in_array.size(); ++i)
    	{
    		if (maximum < in_array[i])
    		{
    			maximum = in_array[i];
    		}
    	}
    	return maximum;
    }

    function min(in_array)
    {
    	var minimum = in_array[0]; 
    	for (var i=0; i < in_array.size(); ++i)
    	{
    		if (minimum > in_array[i])
    		{
    			minimum = in_array[i];
    		}
    	}
    	return minimum;
    }

    function addScalar(in_array, in_scalar)
    {
    	var out_array = in_array;
    	for (var i=0; i < in_array.size(); ++i)
    	{
    		out_array[i] += in_scalar;
    	}
    	return out_array; 
    }
    
    function multiplyByScalar(in_array, in_scalar)
    {
    	var out_array = in_array;
    	for (var i=0; i < in_array.size(); ++i)
    	{
    		out_array[i] *= in_scalar;
    	}
    	return out_array; 
    }
}
class underlordCountdownDelegate extends Toybox.WatchUi.WatchFaceDelegate
{
	function initialize() {
		WatchFaceDelegate.initialize();	
	}

    function onPowerBudgetExceeded(powerInfo) {
        Sys.println( "Average execution time: " + powerInfo.executionTimeAverage );
        Sys.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
        doPartialUpdate=false;
    }
}
