using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.ActivityMonitor as ActMon;

const BATTERY_ICON_WIDTH = 31;
const BATTERY_ICON_HEIGHT = 12;

class ConnectIQView extends Ui.WatchFace {

	var screenShape;
	var screenCenterPoint;
	var dateBuffer;
    var offscreenBuffer;
    var curClip;
	var posnInfo = null;

    function initialize() {
        WatchFace.initialize();
        
        screenShape = System.getDeviceSettings().screenShape;
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
        screenCenterPoint = [dc.getWidth() / 2, dc.getHeight() / 2];
        
        // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        if(Toybox.Graphics has :BufferedBitmap) {
            // Allocate a full screen size buffer with a palette of only 4 colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            offscreenBuffer = new Graphics.BufferedBitmap({
                :width=>dc.getWidth(),
                :height=>dc.getHeight(),
                :palette=> [
                    Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ]
            });

            // Allocate a buffer tall enough to draw the date into the full width of the
            // screen. This buffer is also used for blanking the second hand. This full
            // color buffer is needed because anti-aliased fonts cannot be drawn into
            // a buffer with a reduced color palette
            dateBuffer = new Graphics.BufferedBitmap({
                :width=>dc.getWidth(),
                :height=>Graphics.getFontHeight(Graphics.FONT_MEDIUM)
            });
        } else {
            offscreenBuffer = null;
        }
        
        curClip = null;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    		var width;
        var height;
        var targetDc = dc;
        var hourHandAngle;
        var minuteHandAngle;
        var clockTime = System.getClockTime();
        
        /*
        if(null != offscreenBuffer) {
            dc.clearClip();
            curClip = null;
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDc = offscreenBuffer.getDc();
        } else {
            targetDc = dc;
        }
        */
        
 		width = targetDc.getWidth();
        height = targetDc.getHeight();
    
    		// Clear and fill background
    		targetDc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
    		targetDc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
        
        // Draw tick marks
        targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
        targetDc.setPenWidth(1);
        
        var radian, points;
 
        for (var i = 0; i < 60; i++) {
            // Skip the (three or more) ticks at the top of the hour
            if (i >= 0 && i <= 1 ||
                i >= 14 && i <= 16 ||
                i >= 29 && i <= 31 ||
                i >= 44 && i <= 46 ||
                i == 59) {
                continue;
            }
        
            points = calculateLineFromCircleEdge(width / 2, 6, Math.toRadians(6 * i));
            targetDc.drawLine(points[0], points[1], points[2], points[3]);
        }
        
        targetDc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY);
        targetDc.setPenWidth(5);
        
        for (var i = 0; i < 12; i++) {
            if (i == 0 || i == 3 || i == 6 || i == 9) {
                continue;
            }
            
            radian = Math.toRadians(30 * i);
            points = calculateLineFromCircleEdge(width / 2, 15, radian);
            targetDc.drawLine(points[0], points[1], points[2], points[3]);
        }
        
        // Draw battery
        drawBattery(targetDc, width / 2 - BATTERY_ICON_WIDTH / 2, height - 60);
        
        // Draw time
        targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHandAngle = hourHandAngle / (12 * 60.0);
        hourHandAngle = hourHandAngle * Math.PI * 2;
        targetDc.fillPolygon(generateHandCoordinates(screenCenterPoint, hourHandAngle, 40, 0, 3));
        
        minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
        targetDc.fillPolygon(generateHandCoordinates(screenCenterPoint, minuteHandAngle, 70, 0, 3));
        
        // Draw some text data
        var activityInfo = ActMon.getInfo();
        var string = activityInfo.steps.toString() + " / " + activityInfo.stepGoal.toString() + " steps";
        dc.drawText(width / 2, 40, Gfx.FONT_SYSTEM_XTINY, string, Gfx.TEXT_JUSTIFY_CENTER);
        
        // Draw rest
        drawArborInCenter(targetDc, width, height);        
        drawHourLabels(targetDc, width, height);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }
    
    // Draws the clock tick marks around the outside edges of the screen.
    function drawTickMarks(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Draw hashmarks differently depending on screen geometry.
        if (System.SCREEN_SHAPE_ROUND == screenShape) {
            var sX, sY;
            var eX, eY;
            var outerRad = width / 2;
            var innerRad = outerRad - 10;
            
            // Loop through each 15 minute block and draw tick marks.
            for (var i = Math.PI / 6; i <= 11 * Math.PI / 6; i += (Math.PI / 3)) {
            		//innerRad = innerRad % Math.PI / 6 == 0 ? innerRad - 5 : innerRad;
            
                // Partially unrolled loop to draw two tickmarks in 15 minute block.
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
                
                i += Math.PI / 6;
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
            }
        } else {
            var coords = [0, width / 4, (3 * width) / 4, width];
            for (var i = 0; i < coords.size(); i += 1) {
                var dx = ((width / 2.0) - coords[i]) / (height / 2.0);
                var upperX = coords[i] + (dx * 10);
                // Draw the upper hash marks.
                dc.fillPolygon([[coords[i] - 1, 2], [upperX - 1, 12], [upperX + 1, 12], [coords[i] + 1, 2]]);
                // Draw the lower hash marks.
                dc.fillPolygon([[coords[i] - 1, height-2], [upperX - 1, height - 12], [upperX + 1, height - 12], [coords[i] + 1, height - 2]]);
            }
        }
    }
    
    function drawArborInCenter(targetDc, width, height) {
        // Draw the arbor in the center of the screen.
        targetDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        targetDc.fillCircle(width / 2, height / 2, 7);
        targetDc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        targetDc.drawCircle(width / 2, height / 2, 7);
    }
    
    // This function is used to generate the coordinates of the 4 corners of the polygon
    // used to draw a watch hand. The coordinates are generated with specified length,
    // tail length, and width and rotated around the center point at the provided angle.
    // 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    function generateHandCoordinates(centerPoint, angle, handLength, tailLength, width) {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength], [-(width / 2), -handLength], [width / 2, -handLength], [width / 2, tailLength]];
        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }
    
    function drawHourLabels(targetDc, width, height) {
        // Draw the 3, 6, 9, and 12 hour labels.
        targetDc.setColor(Graphics.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        
        targetDc.drawText((width / 2), 2, Gfx.FONT_SYSTEM_XTINY, "12", Gfx.TEXT_JUSTIFY_CENTER);
        targetDc.drawText(width - 2, (height / 2) - 15, Gfx.FONT_SYSTEM_XTINY, "3", Gfx.TEXT_JUSTIFY_RIGHT);
        targetDc.drawText(width / 2, height - 30, Gfx.FONT_SYSTEM_XTINY, "6", Gfx.TEXT_JUSTIFY_CENTER);
        targetDc.drawText(2, (height / 2) - 15, Gfx.FONT_SYSTEM_XTINY, "9", Gfx.TEXT_JUSTIFY_LEFT);
    }
    
    function drawBattery(dc, batteryX, batteryY) {
    		// Get battery status
    		var battery = Sys.getSystemStats().battery;
    		var batteryStatus = battery.toNumber();
    		
    		dc.setPenWidth(1);
    		
    		// Battery position
    		batteryX = batteryX.toNumber();
    		batteryY = batteryY.toNumber();
    		
    		// Draw placholder
    		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY); 
    		dc.fillRectangle(batteryX, batteryY, BATTERY_ICON_WIDTH, BATTERY_ICON_HEIGHT);
    	
    		// Draw ending small square of battery icon
    		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
    		dc.fillRectangle(batteryX + 31, batteryY + 3, 3, 6);
    		
    		//dc.drawRectangle(batteryX, batteryY, 31, 12);
    		
    		// Draw actual battery status
    		if (battery >= 50) {
    			dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_GREEN);
	    		dc.fillRectangle(batteryX + 1, batteryY + 1, BATTERY_ICON_WIDTH * 0.5 - 1, 10);
	    		    			
    			if (battery >= 60) {
				dc.fillRectangle((batteryX + 1) + (BATTERY_ICON_WIDTH * 0.5), batteryY + 1, 2, 10);		
    			}
    			
    			if (battery >= 70) {
				dc.fillRectangle((batteryX + 1) + (BATTERY_ICON_WIDTH * 0.6), batteryY + 1, 2, 10);		
    			}
    			
    			if (battery >= 80) {
				dc.fillRectangle((batteryX + 1) + (BATTERY_ICON_WIDTH * 0.7), batteryY + 1, 2, 10);		
    			}
    			
    			if (battery >= 90) {
				dc.fillRectangle((batteryX + 1) + (BATTERY_ICON_WIDTH * 0.8), batteryY + 1, 2, 10);		
    			}
    			
    			if (battery == 100) {
				dc.fillRectangle((batteryX + 1) + (BATTERY_ICON_WIDTH * 0.9), batteryY + 1, 2, 10);
				
				// Label
				dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
				dc.drawText(batteryX + BATTERY_ICON_WIDTH + 5, batteryY + 4, Gfx.FONT_SYSTEM_XTINY, "100%", Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);		
    			}
    			
    		} else {
    			//dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);

			if (battery >= 40) {
				dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
    				dc.fillRectangle(batteryX + 1, batteryY + 1, BATTERY_ICON_WIDTH * 0.4 - 1, 10);		
			} else if (battery >= 25) {
				dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_YELLOW);
				dc.fillRectangle(batteryX + 1, batteryY + 1, BATTERY_ICON_WIDTH * 0.25 - 1, 10);
			}

    		}
    }
    
    function drawHeartRate() {
        var HRH = ActMon.getHeartRateHistory(1, true);
        var HRS = HRH.next();
        
        dc.drawText(width / 2, 25, Gfx.FONT_MEDIUM, "max=" + HRH.getMax(), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, 75, Gfx.FONT_MEDIUM, "hr=" + HRS.heartRate, Gfx.TEXT_JUSTIFY_CENTER);
    }
    
    function calculateLineFromCircleEdge(arcRadius, lineLength, radian) {
        var pointX = ((arcRadius-lineLength) * Math.cos(radian)).toNumber() + screenCenterPoint[0];
        var endX = (arcRadius * Math.cos(radian)).toNumber() + screenCenterPoint[0];
        var pointY = ((arcRadius-lineLength) * Math.sin(radian)).toNumber() + screenCenterPoint[1];
        var endY = (arcRadius * Math.sin(radian)).toNumber() + screenCenterPoint[1];
        
        return [pointX, pointY, endX, endY];
    }
    
    function degreesToRadians(degrees) {
        return (degrees * Math.PI / 180);
    }

}
