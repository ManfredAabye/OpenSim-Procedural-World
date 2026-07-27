using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Noise
{
    public class PerlinNoise
    {
        private int[] p;
        private int seed;
        
        public PerlinNoise(int seed)
        {
            this.seed = seed;
            InitPermutationTable();
        }
        
        private void InitPermutationTable()
        {
            p = new int[512];
            int[] permutation = new int[256];
            
            // Fülle mit Werten 0-255
            for (int i = 0; i < 256; i++)
                permutation[i] = i;
            
            // Mische mit Seed
            Random rand = new Random(seed);
            for (int i = 255; i > 0; i--)
            {
                int j = rand.Next(i + 1);
                int temp = permutation[i];
                permutation[i] = permutation[j];
                permutation[j] = temp;
            }
            
            // Verdoppele für einfacheren Zugriff
            for (int i = 0; i < 512; i++)
                p[i] = permutation[i & 255];
        }
        
        public float Generate(float x, float y)
        {
            int X = (int)Math.Floor(x) & 255;
            int Y = (int)Math.Floor(y) & 255;
            
            float xf = x - (float)Math.Floor(x);
            float yf = y - (float)Math.Floor(y);
            
            float u = Fade(xf);
            float v = Fade(yf);
            
            int aa = p[p[X] + Y];
            int ab = p[p[X] + Y + 1];
            int ba = p[p[X + 1] + Y];
            int bb = p[p[X + 1] + Y + 1];
            
            return Lerp(v, Lerp(u, Grad(aa, xf, yf), Grad(ba, xf - 1, yf)),
                          Lerp(u, Grad(ab, xf, yf - 1), Grad(bb, xf - 1, yf - 1)));
        }
        
        private float Fade(float t)
        {
            return t * t * t * (t * (t * 6 - 15) + 10);
        }
        
        private float Lerp(float t, float a, float b)
        {
            return a + t * (b - a);
        }
        
        private float Grad(int hash, float x, float y)
        {
            int h = hash & 3;
            float u = h < 2 ? x : y;
            float v = h < 2 ? y : x;
            return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
        }
    }
}