/*******************************************************************************
*                                                                              *
* Author    :  Angus Johnson                                                   *
* Version   :  4.8.8                                                           *
* Date      :  30 August 2012                                                  *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2010-2012                                         *
*                                                                              *
* License:                                                                     *
* Use, modification & distribution is subject to Boost Software License Ver 1. *
* http://www.boost.org/LICENSE_1_0.txt                                         *
*                                                                              *
* Attributions:                                                                *
* The code in this library is an extension of Bala Vatti's clipping algorithm: *
* "A generic solution to polygon clipping"                                     *
* Communications of the ACM, Vol 35, Issue 7 (July 1992) pp 56-63.             *
* http://portal.acm.org/citation.cfm?id=129906                                 *
*                                                                              *
* Computer graphics and geometric modeling: implementation and algorithms      *
* By Max K. Agoston                                                            *
* Springer; 1 edition (January 4, 2005)                                        *
* http://books.google.com/books?q=vatti+clipping+agoston                       *
*                                                                              *
* See also:                                                                    *
* "Polygon Offsetting by Computing Winding Numbers"                            *
* Paper no. DETC2005-85513 pp. 565-575                                         *
* ASME 2005 International Design Engineering Technical Conferences             *
* and Computers and Information in Engineering Conference (IDETC/CIE2005)      *
* September 24–28, 2005 , Long Beach, California, USA                          *
* http://www.me.berkeley.edu/~mcmains/pubs/DAC05OffsetPolygon.pdf              *
*                                                                              *
*******************************************************************************/

/*******************************************************************************
*                                                                              *
* This is a translation of the C# Clipper library to Flash AS3.                *
* Ported by: Chris Denham                                                      *
* Date: 29 October 2012                                                        *
* http://www.virtualworlds.co.uk                                               *
*                                                                              *
*******************************************************************************/
package com.logicom.geom 
{
	public class ClipperBase
	{
		
		internal static const horizontal:Number = -3.4E+38;
		internal static const loRange:int = 0x3FFFFFFF;          
		internal static const hiRange:int = 0x3FFFFFFF;//FFFFFFFFL; Int64 not suppported 
		
		internal var m_MinimaList:LocalMinima;
		internal var m_CurrentLM:LocalMinima;
		internal var m_edges:Vector.<Vector.<TEdge>> = new Vector.<Vector.<TEdge>>();
		internal var m_UseFullRange:Boolean;

		//------------------------------------------------------------------------------
		
		public static function abs(i:int):int 
		{ 
			return i < 0 ? -i : i; 
		}
		//------------------------------------------------------------------------------

		public static function xor(lhs:Boolean, rhs:Boolean):Boolean 
		{ 
			return !( lhs && rhs ) && ( lhs || rhs ); 
		}
		//------------------------------------------------------------------------------
		
		protected static function pointsEqual(pt1:IntPoint, pt2:IntPoint):Boolean
		{
			return pt1.equals(pt2);
		}
		//------------------------------------------------------------------------------

		internal function pointIsVertex(pt:IntPoint, pp:OutPt):Boolean
		{
			var pp2:OutPt = pp;
			do
			{
				if (pointsEqual(pp2.pt, pt)) return true;
				pp2 = pp2.next;
			}
			while (pp2 != pp);
			return false;
		}
		//------------------------------------------------------------------------------

		internal function pointInPolygon(pt:IntPoint, pp:OutPt, useFulllongRange:Boolean):Boolean
		{
			var pp2:OutPt = pp;
			var result:Boolean = false;
			/*if (useFulllongRange)
			{
				do
				{
					if ((((pp2.pt.Y <= pt.Y) && (pt.Y < pp2.prev.pt.Y)) ||
						((pp2.prev.pt.Y <= pt.Y) && (pt.Y < pp2.pt.Y))) &&
					  new Int128(pt.X - pp2.pt.X) < 
					  Int128.Int128Mul(pp2.prev.pt.X - pp2.pt.X,  pt.Y - pp2.pt.Y) / 
					  new Int128(pp2.prev.pt.Y - pp2.pt.Y))
						result = !result;
					pp2 = pp2.next;
				} while (pp2 != pp);
			}
			else*/
			{
				do
				{
					if ((((pp2.pt.Y <= pt.Y) && (pt.Y < pp2.prev.pt.Y)) ||
						((pp2.prev.pt.Y <= pt.Y) && (pt.Y < pp2.pt.Y))) &&
						(pt.X - pp2.pt.X < (pp2.prev.pt.X - pp2.pt.X) * (pt.Y - pp2.pt.Y) /
						(pp2.prev.pt.Y - pp2.pt.Y))) result = !result;
					pp2 = pp2.next;
				} while (pp2 != pp);
			}
			return result;
		}
		//------------------------------------------------------------------------------

		internal function slopesEqual(e1:TEdge, e2:TEdge, useFullRange:Boolean):Boolean
		{
			/* if (useFullRange)
			{
				return Int128.Int128Mul(e1.ytop - e1.ybot, e2.xtop - e2.xbot) ==
					Int128.Int128Mul(e1.xtop - e1.xbot, e2.ytop - e2.ybot);
			}
			else */
			{
				return (e1.ytop - e1.ybot) * (e2.xtop - e2.xbot) -
					   (e1.xtop - e1.xbot) * (e2.ytop - e2.ybot) == 0;
			}
		}
		//------------------------------------------------------------------------------

		protected function slopesEqual3(pt1:IntPoint, pt2:IntPoint, pt3:IntPoint, 
			useFullRange:Boolean):Boolean
		{
			/*if (useFullRange)
			{
				return Int128.Int128Mul(pt1.Y - pt2.Y, pt2.X - pt3.X) ==
				  Int128.Int128Mul(pt1.X - pt2.X, pt2.Y - pt3.Y);
			}
			else*/
			{
				return (pt1.Y - pt2.Y) * (pt2.X - pt3.X) - (pt1.X - pt2.X) * (pt2.Y - pt3.Y) == 0;
			}
		}
		//------------------------------------------------------------------------------

		protected function slopesEqual4(pt1:IntPoint, pt2:IntPoint, pt3:IntPoint, pt4:IntPoint, 
			useFullRange:Boolean):Boolean
		{
			/*if (useFullRange)
			{
				return Int128.Int128Mul(pt1.Y - pt2.Y, pt3.X - pt4.X) ==
				  Int128.Int128Mul(pt1.X - pt2.X, pt3.Y - pt4.Y);
			}
			else */
			{
				return (pt1.Y - pt2.Y) * (pt3.X - pt4.X) - (pt1.X - pt2.X) * (pt3.Y - pt4.Y) == 0;
			}
		}
		//------------------------------------------------------------------------------

		public function ClipperBase()
		{
			m_MinimaList = null;
			m_CurrentLM = null;
			m_UseFullRange = false;
		}
		//------------------------------------------------------------------------------

		public function clear():void
		{
			disposeLocalMinimaList();
			for (var i:int = 0; i < m_edges.length; ++i)
			{
				for (var j:int  = 0; j < m_edges[i].length; ++j) m_edges[i][j] = null;
				m_edges[i].length = 0; //clear
			}
			m_edges.length = 0; // clear
			m_UseFullRange = false;
		}
		//------------------------------------------------------------------------------

		private function disposeLocalMinimaList():void
		{
			while( m_MinimaList != null )
			{
				var tmpLm:LocalMinima = m_MinimaList.next;
				m_MinimaList = null;
				m_MinimaList = tmpLm;
			}
			m_CurrentLM = null;
		}
		//------------------------------------------------------------------------------

		public function addPolygons(ppg:Polygons, polyType:int/*PolyType*/):Boolean
		{
			var result:Boolean = false;
			for each(var polygon:Polygon in ppg.getPolygons())
				if (addPolygon(polygon, polyType)) result = true;
			return result;
		}
		//------------------------------------------------------------------------------

		public function addPolygon(polygon:Polygon, polyType:int/*PolyType*/):Boolean
		{
			var pg:Vector.<IntPoint> = polygon.getPoints();
			var len:int = pg.length;
			if (len < 3) return false;
			var newPoly:Polygon = new Polygon();
			var p:Vector.<IntPoint> = newPoly.getPoints();
			p.push(pg[0]);
			var j:int = 0;
			for (var i:int = 1; i < len; ++i)
			{

				var maxVal:int;
				if (m_UseFullRange) maxVal = hiRange; else maxVal = loRange;
				if (abs(pg[i].X) > maxVal || abs(pg[i].Y) > maxVal)
				{
					if (abs(pg[i].X) > hiRange || abs(pg[i].Y) > hiRange)
					{
						throw new ClipperException("Coordinate exceeds range bounds");
					}
					maxVal = hiRange;
					m_UseFullRange = true;
				}

				if (pointsEqual(p[j], pg[i]))
				{
					continue;
				}
				else if (j > 0 && slopesEqual3(p[j-1], p[j], pg[i], m_UseFullRange))
				{
					if (pointsEqual(p[j-1], pg[i])) j--;
				} 
				else
				{
					j++;
				}
					
				if (j < p.length)
				{
					p[j] = pg[i]; 
				}
				else
				{
					p.push(pg[i]);
				}
			}
			if (j < 2) return false;

			len = j+1;
			while (len > 2)
			{
				//nb: test for point equality before testing slopes ...
				if (pointsEqual(p[j], p[0])) j--;
				else if (pointsEqual(p[0], p[1]) || slopesEqual3(p[j], p[0], p[1], m_UseFullRange))
					p[0] = p[j--];
				else if (slopesEqual3(p[j - 1], p[j], p[0], m_UseFullRange)) j--;
				else if (slopesEqual3(p[0], p[1], p[2], m_UseFullRange))
				{
					for (i = 2; i <= j; ++i) p[i - 1] = p[i];
					j--;
				}
				else break;
				len--;
			}
			if (len < 3) return false;

			//create a new edge array ...
			var edges:Vector.<TEdge> = new Vector.<TEdge>(len);
			for (i = 0; i < len; i++) edges[i] = new TEdge();
			m_edges.push(edges);

			//convert vertices to a double-linked-list of edges and initialize ...
			edges[0].xcurr = p[0].X;
			edges[0].ycurr = p[0].Y;
			initEdge(edges[len-1], edges[0], edges[len-2], p[len-1], polyType);
			for (i = len - 2; i > 0; --i)
			{
				initEdge(edges[i], edges[i + 1], edges[i - 1], p[i], polyType);
			}
			initEdge(edges[0], edges[1], edges[len-1], p[0], polyType);

			//reset xcurr & ycurr and find 'eHighest' (given the Y axis coordinates
			//increase downward so the 'highest' edge will have the smallest ytop) ...
			var e:TEdge = edges[0];
			var eHighest:TEdge = e;
			do
			{
				e.xcurr = e.xbot;
				e.ycurr = e.ybot;
				if (e.ytop < eHighest.ytop) eHighest = e;
				e = e.next;
			} while ( e != edges[0]);

			//make sure eHighest is positioned so the following loop works safely ...
			if (eHighest.windDelta > 0) eHighest = eHighest.next;
			if (eHighest.dx == horizontal) eHighest = eHighest.next;

			//finally insert each local minima ...
			e = eHighest;
			do {
				e = addBoundsToLML(e);
			} while( e != eHighest );

			return true;
		}
		//------------------------------------------------------------------------------

		private function initEdge(e:TEdge, eNext:TEdge, ePrev:TEdge, pt:IntPoint, polyType:int):void
		{
			e.next = eNext;
			e.prev = ePrev;
			e.xcurr = pt.X;
			e.ycurr = pt.Y;
			if (e.ycurr >= e.next.ycurr)
			{
				e.xbot = e.xcurr;
				e.ybot = e.ycurr;
				e.xtop = e.next.xcurr;
				e.ytop = e.next.ycurr;
				e.windDelta = 1;
			} 
			else
			{
				e.xtop = e.xcurr;
				e.ytop = e.ycurr;
				e.xbot = e.next.xcurr;
				e.ybot = e.next.ycurr;
				e.windDelta = -1;
			}
			setDx(e);
			e.polyType = polyType;
			e.outIdx = -1;
		}
		//------------------------------------------------------------------------------

		private function setDx(e:TEdge):void
		{
			if (e.ybot == e.ytop) e.dx = horizontal;
			else e.dx = (Number)(e.xtop - e.xbot)/(e.ytop - e.ybot);
		}
		//---------------------------------------------------------------------------

		private function addBoundsToLML(e:TEdge):TEdge
		{
			//Starting at the top of one bound we progress to the bottom where there's
			//a local minima. We then go to the top of the next bound. These two bounds
			//form the left and right (or right and left) bounds of the local minima.
			e.nextInLML = null;
			e = e.next;
			for (;;)
			{
				if ( e.dx == horizontal )
				{
					//nb: proceed through horizontals when approaching from their right,
					//    but break on horizontal minima if approaching from their left.
					//    This ensures 'local minima' are always on the left of horizontals.
					if (e.next.ytop < e.ytop && e.next.xbot > e.prev.xbot) break;
					if (e.xtop != e.prev.xbot) swapX(e);
					e.nextInLML = e.prev;
				}
				else if (e.ycurr == e.prev.ycurr) break;
				else e.nextInLML = e.prev;
				e = e.next;
			}

			//e and e.prev are now at a local minima ...
			var newLm:LocalMinima = new LocalMinima();
			newLm.next = null;
			newLm.Y = e.prev.ybot;

			if ( e.dx == horizontal ) //horizontal edges never start a left bound
			{
				if (e.xbot != e.prev.xbot) swapX(e);
				newLm.leftBound = e.prev;
				newLm.rightBound = e;
			} 
			else if (e.dx < e.prev.dx)
			{
				newLm.leftBound = e.prev;
				newLm.rightBound = e;
			} 
			else
			{
				newLm.leftBound = e;
				newLm.rightBound = e.prev;
			}
			newLm.leftBound.side = EdgeSide.LEFT;
			newLm.rightBound.side = EdgeSide.RIGHT;
			insertLocalMinima( newLm );

			for (;;)
			{
				if ( e.next.ytop == e.ytop && e.next.dx != horizontal ) break;
				e.nextInLML = e.next;
				e = e.next;
				if ( e.dx == horizontal && e.xbot != e.prev.xtop) swapX(e);
			}
			return e.next;
		}
		//------------------------------------------------------------------------------

		private function insertLocalMinima(newLm:LocalMinima):void
		{
			if( m_MinimaList == null )
			{
				m_MinimaList = newLm;
			}
			else if( newLm.Y >= m_MinimaList.Y )
			{
				newLm.next = m_MinimaList;
				m_MinimaList = newLm;
			} 
			else
			{
				var tmpLm:LocalMinima = m_MinimaList;
				while( tmpLm.next != null  && ( newLm.Y < tmpLm.next.Y ) )
					tmpLm = tmpLm.next;
				newLm.next = tmpLm.next;
				tmpLm.next = newLm;
			}
		}
		//------------------------------------------------------------------------------

		protected function popLocalMinima():void
		{
			if (m_CurrentLM == null) return;
			m_CurrentLM = m_CurrentLM.next;
		}
		//------------------------------------------------------------------------------

		private function swapX(e:TEdge):void
		{
			//swap horizontal edges' top and bottom x's so they follow the natural
			//progression of the bounds - ie so their xbots will align with the
			//adjoining lower edge. [Helpful in the ProcessHorizontal() method.]
			e.xcurr = e.xtop;
			e.xtop = e.xbot;
			e.xbot = e.xcurr;
		}
		//------------------------------------------------------------------------------

		protected function reset():void
		{
			m_CurrentLM = m_MinimaList;

			//reset all edges ...
			var lm:LocalMinima = m_MinimaList;
			while (lm != null)
			{
				var e:TEdge = lm.leftBound;
				while (e != null)
				{
					e.xcurr = e.xbot;
					e.ycurr = e.ybot;
					e.side = EdgeSide.LEFT;
					e.outIdx = -1;
					e = e.nextInLML;
				}
				e = lm.rightBound;
				while (e != null)
				{
					e.xcurr = e.xbot;
					e.ycurr = e.ybot;
					e.side = EdgeSide.RIGHT;
					e.outIdx = -1;
					e = e.nextInLML;
				}
				lm = lm.next;
			}
			return;
		}
		//------------------------------------------------------------------------------

		public function getBounds():IntRect 
		{
			var result:IntRect = new IntRect(0, 0, 0, 0);
			var lm:LocalMinima = m_MinimaList;
			if (lm == null) return result;
			result.left = lm.leftBound.xbot;
			result.top = lm.leftBound.ybot;
			result.right = lm.leftBound.xbot;
			result.bottom = lm.leftBound.ybot;
			while (lm != null)
			{
				if (lm.leftBound.ybot > result.bottom)
					result.bottom = lm.leftBound.ybot;
				var e:TEdge = lm.leftBound;
				for (; ; )
				{
					var bottomE:TEdge = e;
					while (e.nextInLML != null)
					{
						if (e.xbot < result.left) result.left = e.xbot;
						if (e.xbot > result.right) result.right = e.xbot;
						e = e.nextInLML;
					}
					if (e.xbot < result.left) result.left = e.xbot;
					if (e.xbot > result.right) result.right = e.xbot;
					if (e.xtop < result.left) result.left = e.xtop;
					if (e.xtop > result.right) result.right = e.xtop;
					if (e.ytop < result.top) result.top = e.ytop;

					if (bottomE == lm.leftBound) e = lm.rightBound;
					else break;
				}
				lm = lm.next;
			}
			return result;
		}
	}

}