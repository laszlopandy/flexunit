/**
 * Copyright (c) 2007 Digital Primates IT Consulting Group
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 **/ 
package org.flexunit.async {
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import org.flexunit.events.AsyncEvent;
	import org.flexunit.runner.IRunner;
	
	/** 
	 * The 'eventFired' event is fired when the event specified in the 
	 * TestCase.asyncHandler() method occurs. 
	 * 
	 * The TestCase pends on this event or the 'timerExpired' event before 
	 * moving on to the next test method or asynchronous event.
	 */
	[Event(name="eventFired",type="org.flexunit.events.AsyncEvent")]

	/** 
	 * The 'timerExpired' event is fired when the event specified in the 
	 * TestCase.asyncHandler() method does not occur before the timeout 
	 * specified in the constructor. The TestCase pends on this event or the 
	 * 'eventFired' event before continuing to the next test method or 
	 * asynhronouse event.
	 */
	[Event(name="timerExpired",type="flash.events.Event")]

	/** 
	 * AsyncHandlers are created when the developer calls the TestCase.asyncHandler() 
	 * method.
	 * 
	 * This causes the TestMethod to pend until the named event fires or the 
	 * timeout is reached, effectively preventing the method from failing or 
	 * passing until all outstanding asynchronous activity is resolved. 
	 **/
	public class AsyncHandler extends EventDispatcher {
		public static var EVENT_FIRED:String = "eventFired";
		public static var TIMER_EXPIRED:String = "timerExpired";

        /**
         * @private
         */
		protected static var TIMER_NOT_STARTED:int = 0;
        /**
         * @private
         */
		protected static var TIMER_STARTED:int = 1;
        /**
         * @private
         */
		protected static var TIMER_COMPLETE:int = -1;
		
		/** 
         * @private
         *
		 * Timer used internally to ensure the event specified in the 
		 * TestCase.asyncHandler() method fires before the timeout specified in 
		 * the constructor.
		 */
		protected var timer:FrameTimer;

		/** 
         * @private
         *
		 * Internally used to keep track of the timer's state.
		 */
		protected var timerState:int = TIMER_NOT_STARTED; 

		/** 
		 * A reference to the event handler that should be called if the event named 
		 * in the TestCase.asyncHandler() method fires before the timeout is reached. <br/>
		 * 
		 * The handler is expected to have the follow signature:<br/>
		 * 
		 * <code>public function handleEvent( event:Event, passThroughData:Object ):void {
		 * }</code><br/>
		 * 
		 * The first parameter is the original event object.
		 * The second parameter is a generic object that can optionally be provided by 
		 * the developer when starting a new asynchronous operation.<br/>
		 */
		public var eventHandler:Function;
		
		/** 
		 * The number of milliseconds this class should wait for its handleEvent 
		 * method to be called, before firing a 'timerExpired' event. 
		 */
		public var timeout:int;

		/** 
		 * A generic object that is optionally provided by the developer when starting 
		 * a new asynchronous operation.
		 * 
		 * This generic object is passed to the eventHandler function if it is called. 
		 */
		public var passThroughData:Object = null
		
		/**
		 * A reference to the event handler that should be called if the event named in 
		 * the TestCase.asyncHandler() method does not fire before the timeout is reached. <br/>
		 * 
		 * The handler is expected to have the follow signature:<br/>
		 * 
		 * <code>
		 * public function handleTimeoutEvent( passThroughData:Object ):void {
		 * }</code><br/>
		 * 
		 * The parameter is a generic object that can optionally be provided by the 
		 * developer when starting a new asynchronous operation.<br/>
		 */
		public var timeoutHandler:Function = null;

		/** 
		 * A generic handler called by an unknown object when a specific event fires. 
		 * 
		 * The object and event are known in the TestCase when calling the TestCase.asyncHandler(). 
		 * This class respond to the event by firing a 'eventFired' event if the event occurred 
		 * before the specified timeout.
		 * 
		 * @param event The event being listened for.
		 */
		public function handleEvent( event:Event=null ):void {
			//The event we were waiting for occurred
			//Let the TestCase know if the timer is still running
			//This will be a custom event			
			if ( timerState >= 0 ) {
				//Only enter this if statement if the timer is still running or has nto yet begun
				if ( timer ) { 
					timer.stop();
				}
				timerState = TIMER_COMPLETE;
				dispatchEvent( new AsyncEvent( EVENT_FIRED, false, false, event ) );
			}
		}

		/** 
		 * An event handler that is called by our timer if handleEvent is not called 
		 * before the number of milliseconds specified in the timeout property. 
		 * 
		 * This method dispatches the 'timerExpired' event to inform the testCase.
		 */		
		public function handleTimeout( event:TimerEvent ):void {			
			timer.stop();
			timerState = TIMER_COMPLETE;
			dispatchEvent( new Event( TIMER_EXPIRED ) );
		}

		/** 
		 * Starts the timeout timer for this test. This method is called by the testCase at
		 * the end of the method body
		 */		
		public function startTimer():void {
			if ( timer ) {
				timer.start();
				timerState = TIMER_STARTED;
			}			
		}
		
		/** 
		 * Constructor. 
		 * 
		 * @param eventHandler Method to call when an event occurs.
		 * 
		 * @param timeout Number of milliseconds to wait for an event.
		 * 
		 * @param passThroughData A generic object that can optionally be provided by the 
		 * developer when setting up an synchronous test.
		 * 
		 * @param timeoutHandler A method to call if the timeout occurs before the event.
		 */
		public function AsyncHandler( eventHandler:Function, timeout:int=0, passThroughData:Object = null, timeoutHandler:Function = null, timeoutWaitsForFrames:Boolean = true ) {

			this.eventHandler = eventHandler;
			this.timeout = timeout;
			this.passThroughData = passThroughData;
			this.timeoutHandler = timeoutHandler; 
			
			if ( timeout ) {				
				timer = new FrameTimer( timeout , timeoutWaitsForFrames );
				timer.addEventListener(TimerEvent.TIMER_COMPLETE, handleTimeout );
				timerState = TIMER_NOT_STARTED;

				//We are going to wait to start the timer until the method body of the test completes,
				//however, we will still accept an asynchronous event ahead of time
				//timer.start();
			}
		}
	}
}

import flash.events.EventDispatcher;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.display.Shape;
import flash.utils.getTimer;

class FrameTimer extends EventDispatcher
{
	private var frameDelay:int;
	private var msDelay:Number;

	private var _shape:Shape;

	private var running:Boolean = false;
	private var frameCount:int = 0;
	private var timeStarted:int = 0;

	public function FrameTimer(delay:Number, waitForThirtyFps:Boolean = true)
	{
		_shape = new Shape();
		msDelay = delay;

		if (waitForThirtyFps)
		{
			frameDelay = Math.ceil(delay / 30.);
		}
		else
		{
			frameDelay = 0;
		}

		trace("FrameTimer: created");
	}

	public function start():void
	{
		timeStarted = getTimer();
		frameCount = 0;
		
		trace("FrameTimer: start");

		if (!running)
		{
			_shape.addEventListener(Event.ENTER_FRAME, handleEnterFrame);
			running = true;
		}
	}

	public function stop():void
	{
		if (!running)
		{
			return;
		}

		trace("FrameTimer: stop (elapsed: " + (getTimer() - timeStarted) + ")");

		running = false;
		_shape.removeEventListener(Event.ENTER_FRAME, handleEnterFrame);
	}

	private function handleEnterFrame(e:Event):void
	{
		if (!running)
		{
			_shape.removeEventListener(Event.ENTER_FRAME, handleEnterFrame);
			return;
		}

		var timeElapsed:int = getTimer() - timeStarted;
		frameCount += 1;

		trace("FrameTimer: frame " + frameCount + ", elapsed: " + timeElapsed + ", delay: " + msDelay);

		if (frameCount >= frameDelay && timeElapsed >= msDelay)
		{
			trace("FrameTimer: complete (elapsed: " + timeElapsed + ")");
			dispatchEvent(new TimerEvent(TimerEvent.TIMER_COMPLETE));
		}
	}
}