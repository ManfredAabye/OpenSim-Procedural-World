using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Terrain
{
    public class HeightMap
    {
        private float[,] m_heightmap;
        public int Width { get; private set; }
        public int Height { get; private set; }
        
        public HeightMap(int width, int height)
        {
            Width = width;
            Height = height;
            m_heightmap = new float[width, height];
        }
        
        public float GetHeight(int x, int y)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height)
                return 0;
            
            return m_heightmap[x, y];
        }
        
        public void SetHeight(int x, int y, float height)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height)
                return;
            
            m_heightmap[x, y] = height;
        }
        
        public float GetNormalizedHeight(int x, int y)
        {
            return GetHeight(x, y) / 100.0f; // Normalisierung
        }
        
        public float GetSlope(int x, int y)
        {
            if (x <= 0 || x >= Width - 1 || y <= 0 || y >= Height - 1)
                return 0;
            
            float hx = GetHeight(x + 1, y) - GetHeight(x - 1, y);
            float hy = GetHeight(x, y + 1) - GetHeight(x, y - 1);
            
            return (float)Math.Sqrt(hx * hx + hy * hy);
        }
    }
}