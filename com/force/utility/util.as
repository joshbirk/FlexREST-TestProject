package com.force.utility
{
	import mx.utils.ObjectUtil;
	
	public class util
	{
		public function util()
		{
		}
		
		public static function genericTrace(result:Object, token:Object = null):void {
			trace("Result");
			trace(ObjectUtil.toString(result));
		}
		
		public static function genericError(error:Object, token:Object = null):void {
			trace("Error");
			trace(ObjectUtil.toString(error));
		}
	}
}