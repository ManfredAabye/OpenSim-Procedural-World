using System;
using Nini.Config;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Configuration
{
    public class WorldConfig
    {
        // Terrain Parameter
        public int Seed { get; private set; }
        public float HeightScale { get; private set; }
        public float Frequency { get; private set; }
        public int Octaves { get; private set; }
        public float Lacunarity { get; private set; }
        public float Gain { get; private set; }
        
        // Vegetation Parameter
        public int MaxTrees { get; private set; }
        public int MaxBushes { get; private set; }
        public float ForestCoverage { get; private set; }
        
        // Wasser Parameter
        public float WaterLevel { get; private set; }
        public int RiverCount { get; private set; }
        public int LakeCount { get; private set; }
        
        // Biome Parameter
        public float BiomeScale { get; private set; }
        
        // Siedlungen
        public int MaxSettlements { get; private set; }
        public float SettlementDensity { get; private set; }

        public WorldConfig(IConfig config)
        {
            // Lade Standardwerte oder aus Konfiguration
            Seed = config.GetInt("Seed", DateTime.Now.Millisecond);
            HeightScale = config.GetFloat("HeightScale", 40.0f);
            Frequency = config.GetFloat("Frequency", 0.02f);
            Octaves = config.GetInt("Octaves", 6);
            Lacunarity = config.GetFloat("Lacunarity", 2.0f);
            Gain = config.GetFloat("Gain", 0.5f);
            
            MaxTrees = config.GetInt("MaxTrees", 5000);
            MaxBushes = config.GetInt("MaxBushes", 3000);
            ForestCoverage = config.GetFloat("ForestCoverage", 0.3f);
            
            WaterLevel = config.GetFloat("WaterLevel", 20.0f);
            RiverCount = config.GetInt("RiverCount", 3);
            LakeCount = config.GetInt("LakeCount", 2);
            
            BiomeScale = config.GetFloat("BiomeScale", 0.01f);
            
            MaxSettlements = config.GetInt("MaxSettlements", 5);
            SettlementDensity = config.GetFloat("SettlementDensity", 0.1f);
        }
    }
}