package com.logicom.geom 
{
	public class IntRect 
    {
        public var left:int;
        public var top:int;
        public var right:int;
        public var bottom:int;

        public function IntRect(left:int, top:int, right:int, bottom:int)
        {
            this.left = left; 
			this.top = top;
            this.right = right; 
			this.bottom = bottom;
        }
    }
}