/**
 *
 * AXL Library
 * Copyright 2014-2016 Denis Aleksandrowicz. All Rights Reserved.
 *
 * This program is free software. You can redistribute and/or modify it
 * in accordance with the terms of the accompanying license agreement.
 *
 */
package axl.utils
{
	import flash.display.Stage;
	import flash.events.Event;
	import flash.utils.clearTimeout;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	/** <h3>Tweening engine</h3>
	 * Allows to animate any numeric property of any object within given time.<br>
	 * Animations can be frame-based or time-based. Values can be updated "absolutely" or "incrementally".
	 *  Supports:
	 * <ul>
	 * <li>delay</li>
	 * <li>cycles</li>
	 * <li>intervals</li>
	 * <li>yoyo</li>
	 * <li>callbacks and arguments for callbacks (onStart, onUpdate, onCycle, onYoyoHalf, onComplete)</li>
	 * <li>pause, resume, restart</li>
	 * <li>stop with go to start/end</li>
	 * <li>pre-defined and custom easing functions</li>
	 * <li>destruction or re-usage instances</li>
	 * <li>frame values pre-calculation</li>
	 * <li>dispatching fake frames</li>
	 * <li>static method for creating one off animations - self disposing instances</li>
	 * <li>static method for killing instances by target</li>
	 * </ul>
	 * Well optimized: 4 properties on 2000 objects at 60 FPS */
	public class AO {
		//general
		private static var STG:Stage;
		private static var curFrame:int;
		private static var frameTime:int;
		private static var prevFrame:int;
		
		private static var animObjects:Vector.<AO> = new Vector.<AO>();
		private static var allInstances:Vector.<AO> = new Vector.<AO>();
		private static var easings:Easings = new Easings();
		private static var defaultEasing:Function = easings.easeOutQuad;
		private static var numObjects:int=0;
		private static var numInstances:int = 0;
		
		//internal
		private var propNames:Vector.<String>;
		private var propStartValues:Vector.<Number>;
		private var propEndValues:Vector.<Number>;
		private var propDifferences:Vector.<Number>;
		private var eased:Vector.<Vector.<Number>>;
		private var remains:Vector.<Number>;
		private var prevs:Vector.<Number>;
		
		private var numProperties:int=0
		private var duration:int=0;
		private var passedTotal:int=0;
		private var passedRelative:int=0;
		private var direction:int=1;
		private var cur:Number=0;
		
		private var updateFunction:Function;
		private var getValue:Function;
		private var isPlaying:Boolean;
		private var isSetup:Boolean;
		private var id:int;
		
		// applying anytime
		/** Indicates if animation is going to be played in reverse after reaching standard destination points.<br>
		 * yoyo doubles the initial time of animation and extends length of <code>cycle</code>. Executes <code>onYoyoHalf</code> (if defined) 
		 * on reaching original values (before going back). Reversed animation is played after each "half cycle" rather than after all cycles.<br>
		 * <br>This property can be applied any time during animation and an effect is immediate.
		 * @default false
		 * @see #cycles */
		public var yoyo:Boolean=false;
		/** Determines how many times animation is repeated. Setting this value to 0 results in infinite number of cycles (object is animated
		 * until stopped different way).<br>
		 * Cycles without <code>yoyo</code> repeat animation from start values right after reaching end values.
		 * When yoyo is set to true, cycle is repeated after reversed animation brings object's properties back to start values.
		 * Executes <code>onCycle</code> if defined.
		 * <br>This property can be applied any time during animation and an effect is immediate.
		 * Requested during animation informs how many cycles remained till end. @default 1 
		 * @see #interval @see #yoyo */
		public var cycles:int=1;
		/** Target of an animation. This can be DisplayObject but also can be anything else e.g. volume of sound object, proxy object.
		 *  Requirement is that <code>subject</code> owns all properties to animate passed in <code>props</code> parameter.
		 * Can be changed during animation. */
		public var subject:Object;
		/** Once animation is completed (all yoyo, all cycles) the sequence can be repeated. This property determines number of seconds after which 
		 * is going to happen if <code>intervalRepetitions</code> &gt; 1 
		 * @default 0  @see #yoyo @see #cycles @see #intervalRepetitions */
		public var interval:Number=0;
		/** Determines how many times entire animation sequence (incl. cycles and yoyo's) is going to be executed if <code>interval &gt; 0</code> 
		 * @default 1 @see #interval @see #yoyo @see #cycles */
		public var intervalRepetitions:int=1;
		/** When animation is about to start (e.g delayed or paused) <code>onStart</code> callback  can be fired. 
		 * This vairable can hold an array of arguments for this callback. @see #onStart() */
		public var onStartArgs:Array;
		/** When animation is in progress, after every update on animation target it can fire <code>onUpdate</code> callback
		 * (passed in <i>properties</i> object or set on AO instance). This vairable can hold an array of arguments for that callback. @see #onUpdate() */
		public var onUpdateArgs:Array;
		/** When animation is in progress and <code>yoyo=true</code>, every time object reaches destination values (before reversing to start values),
		 *  <code>onYoyoHalf</code> callback can be fired (passed in <i>properties</i> object or set on AO instance). This vairable can hold
		 *  an array of arguments for that callback. @see #yoyo @see #onYoyoHalf() */
		public var onYoyoHalfArgs:Array;
		/** Animation can be repeated number of times, defined by <code>cycles</code>. Each time one cycle is completed, <code>onCycle</code> callback
		 * (passed in <i>properties</i> object or set on AO instance) can be fired. 
		 * This variable can hold an array of arguments for that callback. @see #onCycle() */
		public var onCycleArgs:Array;
		/** Once animation is complete, <code>onComplete</code> callback can be fired. This variable can hold an array of arguments for that
		 * callback. @see #onComplete() */
		public var onCompleteArgs:Array;
		/** Callback to fire when animation is about to start (e.g. delayed or paused). Can be set on instance or passed in animation properties object.
		 * @see #onStartArgs */
		public var onStart:Function;
		/** Callback to fire when object properties is updated during animation. Typically on every frame of animation. Not fired during delay or paused
		 * states. Can be set on instance or passed in animation properties object @see #onUpdateArgs() */
		public var onUpdate:Function;
		/** Callback to fire every time object reaches destination values (before reversing to start values) <b>if</b> <code>yoyo=true</code> @see #onYoyoHalfArgs */
		public var onYoyoHalf:Function;
		/** Animation can be repeated number of times, defined by <code>cycles</code>. Each time one cycle is completed, <code>onCycle</code> callback
		 * (passed in <i>properties</i> object or set on AO instance) can be fired. If <code>yoyo=true</code>, full cycle is when object
		 * returns back to start values. When <code>yoyo=false</code> <i>onCycle</i> is fired when object values reach end values.
		 *  @see #onCycleArgs() @see #yoyo */
		public var onCycle:Function;
		/** Callback to fire when animation is completed. If interval repetitions are defined, 
		 * fires after all repetitons, otherwise after all cycles. @see #onCompleteArgs() @see #cycles @see #intervalRepetitions */
		public var onComplete:Function;
		/** Determines if animation instance is being disposed once animation is completed. AO instances created used <code>animate</code> method
		 * set this property to true. Destroyed instance can't be re-used - calling <i>start</i>, <i>restart</i> on it will likely cause an error.
		 * Instances which are not destroyed on complete, can be re-used. @default false  */
		public var destroyOnComplete:Boolean = false;
		
		// applying only before start
		private var uIncremental:Boolean=false;
		private var uFrameBased:Boolean=true;
		private var uPrecalculateFrameValues:Boolean=true;
		private var uProps:Object;
		private var uSeconds:Number;
		private var uEasing:Function = defaultEasing;
		private var uDelay:Number;
		
		// live copy 
		private var incremental:Boolean=false;
		private var frameBased:Boolean=true;
		private var precalculateFrameValues:Boolean;
		private var props:Object;
		private var easing:Function;
		private var delayID:uint;
		private var intervalDuration:Number;
		private var intervalRemaining:int;
		private var ucycles:int=1;
		private var intervalLock:Boolean;
		public var intervalMinusDuration:Boolean;
		private var durationPassed:Boolean;
		private var intervalPassed:Boolean;
		private var intervalRepetitionsPassed:Boolean;
		
		/** Destroys an instance and makes it un-usable.
		 * <ul><li>stops any animation and removes it from pool (incl. stopped, paused and delayed ones)</li>
		 * <li>disposes all internal objects</li>
		 * <li>removes refference to the subject and to all callbacks</li>
		 * </ul> @param executeOnComplete - determines if <code>onComplete</code> callback should be executed before destruction */
		public function destroy(executeOnComplete:Boolean=false):void
		{
			//# trace('[AO][destroy]'+ subject);
			clearTimeout(delayID);
			delayID = 0;
			removeFromPool();
			removeFromInstances();
			numProperties = duration = passedTotal = passedRelative = cur = uSeconds = 0;
			propStartValues = propEndValues = propDifferences = remains =  prevs = null;
			propNames = null;
			eased = null;
			direction = cycles = 1;
			subject = props = uProps = null;
			onUpdateArgs = onYoyoHalfArgs = onCycleArgs = null;
			updateFunction = getValue = easing = uEasing = onUpdate = onYoyoHalf = onCycle = null;
			
			if(executeOnComplete && (onComplete != null))
				onComplete.apply(null, onCompleteArgs);
			
			onCompleteArgs = null;
			onComplete = null;
		}
		
		private function removeFromInstances():void
		{
			var i:int = allInstances.indexOf(this);
			if(i>-1) 
			{
				allInstances.splice(i,1);
				numInstances--;
				isPlaying = false;
			}
		}
		/** Creates re-usable, not self starting AO instance. Requires to call <code>start</code>
		 * after set up.
		 * If you're not going to re-use it, use static method <code>AO.animate</code> which 
		 * gives all options this instance would give but with just one line.<br>
		 * Re-usable instances are good for optimization. Animations executed big number of times 
		 * on the same target and/or with the same set of settings should be subject of optimization.
		 * set of settings and executed. In all other cases static method is fine. 
		 * @param subject - object you want to animate
		 * @param properties - key-values object of properties to animate and its destination values. E.g. 
		 * <code>{ x : 220, y : 100, rotation : 360 }</code> 
		 * @see #start() @see axl.utils.AO#animate() */
		public function AO(subject:Object, seconds:Number, properties:Object) {
			/*if(STG == null)
				throw new Error("[AO]Stage not set up!");*/
			allInstances[numInstances++] = this;
			uSeconds = seconds;
			uProps = properties;
			if(uProps.hasOwnProperty('delay'))
				delay = uProps.delay;
			this.subject = subject;
		}
		
		private function setUp():void
		{
			//# U.log('[AO][setup]' + subject);
			prepareCommon();
			if(incremental) prepareIncremental();
			else prepareAbsolute();
			
			if(frameBased) prepareFrameBased();
			else prepareTimeBased();
			isSetup = true;
			ucycles = cycles;
		}
		
		private function prepareCommon():void
		{
			if(propNames) propNames.length = 0; else propNames = new Vector.<String>();
			if(propStartValues) propStartValues.length = 0; else propStartValues = new Vector.<Number>();
			if(propEndValues) propEndValues.length = 0; else propEndValues = new Vector.<Number>();
			if(propDifferences) propDifferences.length = 0; else propDifferences = new Vector.<Number>();
			
			numProperties = duration = passedTotal = passedRelative = cur = intervalDuration= intervalRemaining = 0;
			
			props = uProps;
			easing = uEasing || defaultEasing;
			precalculateFrameValues = uPrecalculateFrameValues;
			frameBased = uFrameBased;
			incremental = uIncremental;
			
			for(var s:String in props)
			{
				if(subject.hasOwnProperty(s) && !isNaN(subject[s]) && !isNaN(props[s]))
					propNames[numProperties++] = s;
				else if(this.hasOwnProperty(s))
					this[s] = props[s];
				else throw new ArgumentError("[AO]" + subject + " Invalid property '"+s+"' or value: " + props[s]);  
			}
		}
		
		// ----------------------------------------- PREPARE ----------------------------------- //
		private function prepareIncremental():void
		{
			if(prevs) prevs.length = 0; else prevs = new Vector.<Number>();
			if(remains) remains.length = 0; else remains = new Vector.<Number>();
			updateFunction = updateIncremental;
			for(var i:int=0; i<numProperties;i++)
			{
				propDifferences[i] = props[propNames[i]];
				propStartValues[i] = subject[propNames[i]];
				propEndValues[i] = propStartValues[i] + propDifferences[i];
				remains[i] = propDifferences[i];
				prevs[i] = propStartValues[i];
			}
		}
		
		private function prepareAbsolute():void
		{
			updateFunction = updateAbsolute;
			for(var i:int=0; i<numProperties;i++)
			{
				propStartValues[i] = subject[propNames[i]];
				propEndValues[i] = props[propNames[i]];
				propDifferences[i] = props[propNames[i]] - subject[propNames[i]];
			}
		}
		
		private function prepareTimeBased():void {
			duration  =  (uSeconds * 1000); 
			intervalDuration = intervalRemaining = (interval * 1000);
			getValue = getValueLive;
		}
		private function prepareFrameBased():void
		{
			duration = Math.ceil(STG.frameRate * uSeconds); // no frames
			intervalDuration = intervalRemaining = Math.ceil(STG.frameRate * interval);
			if(!precalculateFrameValues)
				getValue = getValueLive;
			else 
			{
				getValue = getValueEased;
				eased = new Vector.<Vector.<Number>>(numProperties,true);
				var i:int, j:int;
				for(i=0;i<numProperties;i++)
				{
					eased[i] = new Vector.<Number>(duration,true);
					for(j=0; j < duration;j++) 
						eased[i][j] = easing(j, propStartValues[i], propDifferences[i], duration);
				}
			}
		}
		// ----------------------------------------- UPDATE ------------------------- //
		/** Main propeller of animation engine. It's used to broadcast new frame and compute state of continuation.*/
		protected function tick(milsecs:int):void
		{
			passedTotal += frameBased ? 1 : milsecs;
			passedRelative = (direction < 0) ? (duration - passedTotal) : passedTotal;
			durationPassed = passedTotal >= duration;
			var continues:Boolean;
			if(interval > 0)
			{
				// ---------------- COMPUTING STATE -------------------- //
				if(intervalMinusDuration)
				{
					intervalRemaining -= frameBased ? 1 : milsecs;
				}
				else if(intervalLock)
				{
					intervalRemaining -= frameBased ? 1 : milsecs;
				}
				intervalPassed = (intervalRemaining <= 0);
				if(intervalPassed)
				{
					intervalRepetitions--
				}
				intervalRepetitionsPassed = (intervalRepetitions <= 0);
				
				// ----------------  TAKING ACTIONS ---------------- //
				if(intervalRepetitionsPassed)
				{
					intervalLock = false;
					finish(true);
					return;
				}
				else if(intervalPassed)
				{
					// need to know if contunues? 
					//no! as this is being decided on end of regular period
					// simply restarts the animation
					passedTotal = 0;
					cycles = ucycles;
					intervalLock  = false
					intervalRemaining = intervalDuration;
					
				}
				else // interval not passed but set
				{
					
					if(!intervalLock) // for the first time!	
					{
						// need to know if to ease
						//first need to know if regular animation or interval waiting
						if(durationPassed)
						{
							continues = passedDuration(); // determines if to go back or smth
							if(continues)
							{
								passedTotal = 0; // waits for another tick (yoyo e.g.
							}
							else
							{
								intervalLock = true; // eased, closed
							}
						}
						else //  interval set but not locked, duration not passed, - regular tick dispatch
						{
							updateFunction();
							if(onUpdate is Function)
								onUpdate.apply(null, onUpdateArgs);
						}
					}
					else // already locked so probably eased and resolved continuation
					{
						// just tick
					}
					
				}
			}
			else // THIS HAS NOTHING TO DO WITH INTERVALS
			{
				if(durationPassed) // end of period
				{
					continues = passedDuration(); // determines if to go back or smth
					if(continues)
					{
						passedTotal = 0; // waits for another tick (yoyo e.g.
					}
					else
					{
						finish(true); // ends an animation
					}
				}
				else // regular tick dispatch
				{
					updateFunction();
					if(onUpdate is Function)
						onUpdate.apply(null, onUpdateArgs);
				}
			}
			
		}
		
		private function resolveInterval(ms:uint):void
		{
			if(intervalPassedd(ms))
			{
				intervalLock = false;
				finish(true);
			}
			else
			{
				intervalLock = true;
			}
		}
		private function intervalPassedd(milsecs:int):Boolean
		{
			if(interval <= 0)
				return true;
			intervalRemaining -= frameBased ? 1 : milsecs;
			if(intervalRemaining <= 0)
			{
				if(--intervalRepetitions < 0)
					return true;
				else
				{
					passedTotal = 0;
					cycles = ucycles;
					intervalLock  = false
					intervalRemaining = intervalDuration;
					return false
				}
			}
			else
			{
				return false;
			}
		}		
		
		//absolute
		private function updateAbsolute():void
		{
			for(var i:int=0;i<numProperties;i++)
				subject[propNames[i]] = getValue(i);
		}
		
		//inctemental
		private function updateIncremental():void
		{
			for(var i:int=0;i<numProperties;i++)
			{
				cur = getValue(i);
				var add:Number = (cur - prevs[i]);
				var bug:Number = subject[propNames[i]];
				subject[propNames[i]] += add;
				bug = (subject[propNames[i]] - add) - bug;
				remains[i] += (-add * direction) - bug;
				prevs[i] = cur;
			}
		}
		
		//common
		private function getValueEased(i:int):Number
		{
			return eased[i][passedRelative];
		}
		private function getValueLive(i:int):Number
		{
			return easing(passedRelative, propStartValues[i], propDifferences[i], duration);
		}
		
		private function passedDuration():Boolean
		{
			equalize();
			if(onUpdate is Function) onUpdate.apply(null, onUpdateArgs);
			return resolveContinuation();
		}
		
		private function equalize():void
		{
			//# U.log('[AO][equalize]' + subject ,'|cycle:'+ +cycles+'|direction:'+ direction);
			if(!incremental) 
				if(direction > 0) 
					applyValues(propEndValues); 	// | > > > > > > [HERE]|
				else				
					applyValues(propStartValues);	// |[HERE] < < < < < < |
			else 		
				applyRemainings();
		}
		/** this is for incrementals only **/
		private function applyRemainings():void
		{
			for(var i:int=0;i<numProperties;i++)
			{
				subject[propNames[i]] += remains[i] * direction;
				remains[i] = propDifferences[i];
			}
			if(!yoyo || (yoyo && direction < 0))
				for(i=0; i < numProperties; i++)
					prevs[i] = propStartValues[i];
			else
				for(i=0; i < numProperties; i++)
					prevs[i] = propEndValues[i];
		}
		/** this is for absolutes only **/
		private function applyValues(v:Vector.<Number>):void
		{
			for(var i:int=0;i<numProperties;i++)
				subject[propNames[i]] = v[i];
		}
		
		private function resolveContinuation():Boolean
		{
			//# U.log("------resolveContinuation----------");
			if(yoyo)
			{
				if(direction > 0)
				{
					direction = -1;
					dispatchHalfYoyo();
					return true;
				}
				else
				{
					direction = 1;
					return cycled();
				}
			} 
			else 
				return cycled();
		}
		
		private function dispatchHalfYoyo():void
		{
			if(onYoyoHalf is Function)
				onYoyoHalf.apply(null, onYoyoHalfArgs);
		}
		
		private function cycled():Boolean
		{
			--cycles;
			if(onCycle is Function) 
				onCycle.apply(null, onCycleArgs);
			if(cycles == 0)
				return false;
			return true
		}
		
		//-------------------- controll ------------------//
		private function finish(dispatchComplete:Boolean,forceDestroy:Boolean=false):void { 
			//# U.log('[Easing][finish]',subject,destroyOnComplete);
			clearTimeout(delayID);
			if(destroyOnComplete || forceDestroy)
				destroy(dispatchComplete);
			else
			{
				pause();
				if(onComplete != null && dispatchComplete)
					onComplete.apply(null, onCompleteArgs);
			}
		}
		
		private function gotoEnd():void
		{
			//# U.log('[Easing][gotoEND]',subject);
			equalize();
			if(yoyo && (direction > 0))
			{
				direction = -1;
				equalize();
			}
			direction = 1;
			passedTotal = 0;
		}
		
		private function gotoStart():void
		{
			//# U.log('[Easing][gotoSTART]',subject);
			equalize();
			if(direction > 0)
			{
				direction = -1;
				equalize();
			}
			direction = 1;
			passedTotal = 0;
		}
		
		private function removeFromPool():void
		{
			var i:int = animObjects.indexOf(this);
			if(i>-1) 
			{
				animObjects.splice(i,1);
				numObjects--;
				isPlaying = false;
			}
		}

		private function perform():void 
		{ 
			clearTimeout(delayID);
			delayID = 0;
			if(!isSetup)
				setUp();
			if(!isPlaying)
			{
				AO.animObjects[numObjects++] = this;
				isPlaying = true;
				if(onStart is Function) onStart.apply(null, onStartArgs);
			}
		}
		
		// ---------------------------------- public instance API------------------------------------------ //
		/** Returns <code>true</code> if object is actively being updated every frame. 
		 * Returns <code>false</code> for stopped, paused, completed and delayed (if delay hasn't pased yet) animations */
		public function get isAnimating():Boolean { return isPlaying }
		
		/** Starts animation if not started yet, stopped or paused.
		 * @param respectDelay - If there's a delay assigned to animation - respecting delay will cause delayed start, 
		 * otherwise animation will start promptly */
		public function start(respectDelay:Boolean=true):void
		{
			if(delay > 0 && respectDelay)
				delayID = flash.utils.setTimeout(perform, delay * 1000);
			else
				perform();
		}
		/** Starts or continues an animation without respecting delay assigned to it.  @see #start() */
		public function resume():void { start(false) };
		
		/** Pauses an animation immediately. Animation can be resumed from the moment it was paused by calling <code>resume</code> @see #resume() */
		public function pause():void { removeFromPool() };
		
		/** Stops an animation promptly and sets object values according to <code>goToDirection</code> parameter.
		 *  @param goToDirection: 
		 * <ul><li>negative - start (initial) values</li><li> 0 - stays still</li><li>positive - end values</li></ul>
		 * @param readNchanges - determines if animation properties should be re-read before eventual calls 
		 * to <i>start</i> or <i>resume</i> methods */
		public function stop(goToDirection:int=0, readNchanges:Boolean=false):void
		{
			//# U.log('[AO][Stop]'+subject);
			removeFromPool();
			if(goToDirection > 0) gotoEnd();
			else if(goToDirection < 0) gotoStart();
			isSetup = !readNchanges;
		}
		
		/** Restarts an animation instantly (stops it, goes to direction and calls start).
		 *  @param goToDirection: 
		 * <ul><li>negative - start (initial) values</li><li> 0 - stays still</li><li>positive - end values</li></ul>
		 * @param  readNchanges - determines if animation properties should be re-read before start */
		public function restart(goToDirection:int,readNchanges:Boolean=false):void
		{
			stop(goToDirection,readNchanges);
			start();
		}
		
		/** Stops animation before it's completed. 
		 * @param completeImmediadely - if true - applies end values to subject of animation and fires <code>onComplete</code> callback
		 * if defined. If false either pauses or destroys an instance - depending on <code>destroyOnComplete</code> flag.   */
		public function finishEarly(completeImmediately:Boolean,forceDestroy:Boolean=false):void
		{
			//# U.log('[Easing][finishEarly]',completeImmediately);
			if(completeImmediately)
			{
				gotoEnd();
				finish(true,forceDestroy);
			}
			else finish(false,forceDestroy);
		}
		
		// changes that require stop and re-read;
		/** Determines if updates on target are applied with respect to its current momentum values (true) or as an absolute values (false).
		 * When object properties are modified by more than one source (e.g. user interaction or multiple animation objects operates on the 
		 * same property), non inctemental updates can cause jerkiness. Incremental updates allows to overcome that but require user to  
		 * calculate destination values relatively to it's current position. */
		public function get nIncremental():Boolean { return incremental }
		public function set nIncremental(v:Boolean):void { uIncremental = v }
		
		/** Animations can be frame based or time based. 
		 * <h3>Frame based animations</h3>
		 * Can take longer to complete then time assigned to it.<br>
		 * When performance drops down in the project - average frame time extends and so does animation time. In this case animation will be
		 * slower but smooth because all "portions of animation" match number of frames and are rendered frame by frame. 
		 * <h3>Time based animations</h3>
		 * Time passed between each and every frame is calculated, object is updated accordingly. "Portions of animation"  are rated after each frame 
		 * individually. In this case total animation duration matches animation time assigned, but in case of performance drop,
		 *  it may become "jumpy" and may finish before expected or beofre other frame based animations (e.g. MovieClip). */
		public function get nFrameBased():Boolean { return frameBased }
		public function set nFrameBased(v:Boolean):void { uFrameBased = v }
		
		/** This property applies only for frame based animations (<code>nFrameBased = true</code>). Allows to pre-calculate frame values, which can
		 *  improve overal performance during animation, moving calculations weight to the very first frame of it. Usefull for long animations on many
		 *  properties. @see nFrameBased */
		public function get nPrecalculateFrameValues():Boolean { return precalculateFrameValues }
		public function set nPrecalculateFrameValues(v:Boolean):void {  uPrecalculateFrameValues = v }
		
		/** Key-value object containing keys as properties to animate (e.g. x,y,scale,rotation) 
		 * and destination values for them PLUS public properties of this class from list bellow:
		 * <ul>
		 * <li>yoyo</li><li>cycles</li><li>subject</li>
		 * <li>interval</li><li>intervalRepetitions</li><li>onStartArgs</li>
		 * <li>onUpdateArgs</li><li>onYoyoHalfArgs</li><li>onCycleArgs</li>
		 * <li>onCompleteArgs</li><li>onStart</li><li>onUpdate</li><li>onYoyoHalf</li>
		 * <li>onCycle</li></ul> 
		 * Every property passed in nProperties can override values set directly on instance or passed to <code>animate</code>
		 * method.<br>
		 * Example object: <code>{ x : 220, y : 100, rotation : 360, onUpdate : someFunction }</code> */
		public function get nProperties():Object { return props }
		public function set nProperties(v:Object):void { uProps = v }
		
		/** Duration of animation in seconds @see #nFrameBased */
		public function get nSeconds():Number { return uSeconds }
		public function set nSeconds(v:Number):void { uSeconds = v }
		
		/** Animations can be eased  by easing function. This can be custom function or one from predefined in
		 * <code>axl.utils.Easings</code> class, also available as static property of this class.<br><br>
		 * Custom easing functions needs to return Number based on four arguments function must accept:
		 * current time, start value, change in value, duration.  
		 * @see axl.utils.AO#easing */
		public function get nEasing():Function { return easing }
		public function set nEasing(v:Function):void { uEasing = v }
		
		/**Delay time in seconds before animation starts. Delay can be omitted by calling <code>start(false)</code> 
		 * Delayed animations can be killed, stopped, paused and return <code>false</code> on queries 
		 * <code>isAnimating</code> but <code>true</code> on queries  <code>AO.contains</code>*/
		public function get delay():Number { return uDelay }
		public function set delay(v:Number):void { uDelay = v }
		
		// -----------------------  PUBLIC STATIC ------------------- //
		/** Exposes easing functions for animation easings @see axl.utils.Easing @see #nEasing*/
		public static function get easing():Easings { return easings };
		
		/** Stops any existing animations assinged to target (including paused, stopped and delayed). 
		 * If <code>destroyOnComplete = true</code> also destroys AO instance.
		 * @param target - either object you animate or AO instance 
		 * @param completeImmediately - determines if destination values should be assigned to target */
		public static function killOff(target:Object, completeImmediately:Boolean=false):void
		{
			//# U.log('[Easing][killOff]', target);
			var i:int = numObjects;
			if(target is AO)
				for(i= 0; i < numInstances;i++)
					if(allInstances[i] == target)
						allInstances[i--].finishEarly(completeImmediately,true);
					
			if(!(target is AO))
				for(i = 0; i < numInstances;i++)
					if(allInstances[i].subject === target)
						allInstances[i--].finishEarly(completeImmediately,true);
		}
		/** Returns true if target is subject of any animation (incl. delayed, paused, stopped), false otherwise */
		public static function contains(target:Object):Boolean
		{
			var i:int = numInstances;
			if(target is AO)
				while(i-->0)
					if(allInstances[i] == target)
						return true;
			if(!(target is AO))
				while(i-->0)
					if(allInstances[i].subject === target)
						return true;
			return false;
		}
		
		/** Allows to artificialy speed up all animations by dispatching fake enter frame.
		 * @param frameTime for time based animations is number of milliseconnds that passed since last frame.
		 * For frame based animations its 1, autimatically.
		 * @see #nFrameBased @see #tick()  */
		public static function broadcastFrame(frameTime:int):void
		{
			for(var i:int = 0; i < numObjects;i++)
				animObjects[i].tick(frameTime);
		}
		
		/** Setting stage to null can stop all animations instantly. Setting stage to the actual stage is 
		 * needed in order for AO to work. This should be done as soon as possible in your project, since it's 
		 * not available for this engine to work without stage reference. */
		public static function set stage(v:Stage):void
		{
			if(STG != null) 
				STG.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			STG = v;
			if(STG != null) 
				STG.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		/** Receives frame, calculates time passed since last frame and broadcasts it to all AO instances */
		protected static function onEnterFrame(event:Event):void
		{
			curFrame = getTimer();
			frameTime = curFrame - prevFrame;
			prevFrame = curFrame;
			broadcastFrame(frameTime);
		}
		
		/** Animates object according to parameters passed.<br>
		 *  This is core static function to perform custom, complex animations without instantaiting AO manually, to do it 
		 * in one line. By default all AO instances created by this function are going to be destroyed once animation
		 * is completed.
		 * @param subject - object you want to animate
		 * @param seconds - duration of animation in seconds
		 * @param props - key-values object of properties to animate and its destination values. E.g. 
		 * <code>{ x : 220, y : 100, rotation : 360 }</code>
		 * @param  onComplete - callback function to execute once animation is completed 
		 * @param cycles - number of times to repeat animation instantly
		 * @param yoyo - once reached destination values, determines if animation is going to play in reverse (back
		 * to start values)
		 * @param easingType - function to make your animation smooth, bouncy, elastic or other
		 * @param incremental - determines if updates on object respect it's current values (adds the difference) or update with 
		 * absolute values 
		 * @param frameBased - determines if animation time is affected by performance 
		 * @see #nProperties @see #onComplete @see #cycles  @see #yoyo @see #nEasing @see #nIncremental @see #nFrameBased*/
		public static function animate(subject:Object, seconds:Number, props:Object, onComplete:Function=null, cycles:int=1,yoyo:Boolean=false,
											   easingType:Object=null, incremental:Boolean=false,frameBased:Boolean=true):AO
		{
			if(STG == null)
				throw new Error("[AO]Stage not set");
			var ao:AO = new AO(subject, seconds, props);
			ao.onComplete = onComplete || ao.onComplete;
			ao.cycles = cycles;
			ao.yoyo = yoyo;
			ao.nEasing = (easing.hasOwnProperty(easingType)) ?  easing[easingType] : easingType as Function ;
			ao.nIncremental = incremental;
			ao.nFrameBased = frameBased;
			ao.destroyOnComplete=true;
			ao.start();
			return ao;
		}
	}
}