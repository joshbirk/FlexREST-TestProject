package com.force.utility
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	
	public class filesystem
	{
		public function filesystem()
		{
			
			
		}
		
		public static function saveFile(o:Object,name:String):void {
			trace(typeof(o));
			var myFile:File = File.documentsDirectory.resolvePath(name);  
			var fs:FileStream = new FileStream();  
			var bytes:ByteArray = o as ByteArray;
			
			fs.open(myFile,FileMode.WRITE);  
			fs.writeBytes(bytes,0,bytes.length);  
			fs.close(); 
			trace("Written"); 
		}
	}
}