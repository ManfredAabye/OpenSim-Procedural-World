using System;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Noise;
using OpenSim.Region.OptionalModules.WorldGenerator.Terrain;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Biomes
{
    public class BiomeGenerator
    {
        private WorldConfig m_config;
        private PerlinNoise m_temperatureNoise;
        private PerlinNoise m_humidityNoise;
        
        public BiomeGenerator(WorldConfig config)
        {
            m_config = config;
            m_temperatureNoise = new PerlinNoise(config.Seed + 1);
            m_humidityNoise = new PerlinNoise(config.Seed + 2);
        }
        
        public BiomeMap GenerateBiomeMap(int width, int height, HeightMap heightmap)
        {
            var biomeMap = new BiomeMap(width, height);
            
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    float nx = x * m_config.BiomeScale;
                    float ny = y * m_config.BiomeScale;
                    
                    // Temperatur (abhängig von Höhe und Breitengrad)
                    float temperature = CalculateTemperature(heightmap.GetHeight(x, y), y, height);
                    
                    // Feuchtigkeit (abhängig von Niederschlag und Höhe)
                    float humidity = CalculateHumidity(heightmap.GetHeight(x, y), nx, ny);
                    
                    // Bestimme Biome basierend auf Temperatur und Feuchtigkeit
                    BiomeType biome = DetermineBiome(temperature, humidity, heightmap.GetHeight(x, y));
                    
                    biomeMap.SetBiome(x, y, biome);
                    
                    // Speichere zusätzliche Daten
                    biomeMap.SetTemperature(x, y, temperature);
                    biomeMap.SetHumidity(x, y, humidity);
                }
            }
            
            return biomeMap;
        }
        
        private float CalculateTemperature(float height, int y, int heightMapHeight)
        {
            // Temperatur sinkt mit Höhe und steigt zum Äquator
            float latitudeFactor = 1.0f - Math.Abs((float)y / heightMapHeight - 0.5f) * 2.0f;
            float heightFactor = 1.0f - height / 100.0f;
            
            return Math.Max(0, Math.Min(1, (latitudeFactor * 0.6f + heightFactor * 0.4f)));
        }
        
        private float CalculateHumidity(float height, float nx, float ny)
        {
            // Feuchtigkeit durch Rauschen und Höhe beeinflusst
            float noise = m_humidityNoise.Generate(nx, ny) * 0.5f + 0.5f;
            float heightFactor = 1.0f - height / 80.0f;
            
            return Math.Max(0, Math.Min(1, noise * 0.7f + heightFactor * 0.3f));
        }
        
        private BiomeType DetermineBiome(float temperature, float humidity, float height)
        {
            if (height < m_config.WaterLevel)
            {
                if (height < m_config.WaterLevel - 5.0f)
                    return BiomeType.DeepWater;
                return BiomeType.Water;
            }
            
            if (height > 70.0f)
                return BiomeType.Mountain;
            
            if (height > 50.0f)
                return BiomeType.Highland;
            
            // Temperatur- und Feuchtigkeits-Klassifizierung
            if (temperature > 0.7f)
            {
                if (humidity > 0.6f)
                    return BiomeType.TropicalRainforest;
                else if (humidity > 0.3f)
                    return BiomeType.Savanna;
                else
                    return BiomeType.Desert;
            }
            else if (temperature > 0.4f)
            {
                if (humidity > 0.6f)
                    return BiomeType.TemperateForest;
                else if (humidity > 0.3f)
                    return BiomeType.Grassland;
                else
                    return BiomeType.Scrubland;
            }
            else
            {
                if (humidity > 0.6f)
                    return BiomeType.Taiga;
                else if (humidity > 0.3f)
                    return BiomeType.Tundra;
                else
                    return BiomeType.PolarDesert;
            }
        }
    }
}