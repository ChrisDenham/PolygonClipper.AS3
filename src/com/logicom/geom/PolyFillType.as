package com.logicom.geom 
{
	final public class PolyFillType
	{
		//By far the most widely used winding rules for polygon filling are
		//EvenOdd & NonZero (GDI, GDI+, XLib, OpenGL, Cairo, AGG, Quartz, SVG, Gr32)
		//Others rules include Positive, Negative and ABS_GTR_EQ_TWO (only in OpenGL)
		//see http://glprogramming.com/red/chapter11.html

		public static const EVEN_ODD:int = 0;
		public static const NON_ZERO:int = 1;
		public static const POSITIVE:int = 2;
		public static const NEGATIVE:int = 3;
	}
}