using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Noise
{
    public class FBMNoise
    {
        private PerlinNoise m_perlin;
        private int m_octaves;
        private float m_lacunarity;
        private float m_gain;
        private float m_frequency;
        
        public FBMNoise(int seed, int octaves = 6, float lacunarity = 2.0f, float gain = 0.5f)
        {
            m_perlin = new PerlinNoise(seed);
            m_octaves = octaves;
            m_lacunarity = lacunarity;
            m_gain = gain;
            m_frequency = 1.0f;
        }
        
        public float Generate(float x, float y, float frequency = 1.0f)
        {
            float value = 0;
            float amplitude = 1.0f;
            float maxAmplitude = 0;
            float freq = frequency;
            
            for (int i = 0; i < m_octaves; i++)
            {
                value += m_perlin.Generate(x * freq, y * freq) * amplitude;
                maxAmplitude += amplitude;
                amplitude *= m_gain;
                freq *= m_lacunarity;
            }
            
            return value / maxAmplitude; // Normalisieren auf [-1, 1]
        }
        
        public void SetFrequency(float frequency)
        {
            m_frequency = frequency;
        }
    }
}