using System;
using System.Collections.Generic;
using System.Reflection;
using log4net;
using Nini.Config;
using OpenSim.Framework;
using OpenSim.Region.Framework.Interfaces;
using OpenSim.Region.Framework.Scenes;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Terrain;
using OpenSim.Region.OptionalModules.WorldGenerator.Biomes;
using OpenSim.Region.OptionalModules.WorldGenerator.Vegetation;

namespace OpenSim.Region.OptionalModules.WorldGenerator
{
    public class WorldGeneratorModule : ISharedRegionModule
    {
        private static readonly ILog m_log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        
        private bool m_enabled = false;
        private WorldConfig m_config;
        private WorldManager m_worldManager;
        private TerrainGenerator m_terrainGenerator;
        private BiomeGenerator m_biomeGenerator;
        private ForestGenerator m_forestGenerator;

        public string Name => "WorldGeneratorModule";
        public Type ReplaceableInterface => null;

        public void Initialise(IConfigSource source)
        {
            IConfig config = source.Configs["WorldGenerator"];
            if (config == null)
            {
                m_log.Info("[WORLD GENERATOR]: Module not configured, disabled.");
                return;
            }

            m_enabled = config.GetBoolean("Enabled", false);
            if (!m_enabled)
            {
                m_log.Info("[WORLD GENERATOR]: Module disabled.");
                return;
            }

            m_log.Info("[WORLD GENERATOR]: Initializing...");
            m_config = new WorldConfig(config);
            
            // Initialisiere Komponenten
            m_worldManager = new WorldManager(m_config);
            m_terrainGenerator = new TerrainGenerator(m_config);
            m_biomeGenerator = new BiomeGenerator(m_config);
            m_forestGenerator = new ForestGenerator(m_config);
        }

        public void PostInitialise()
        {
            if (!m_enabled) return;
            m_log.Info("[WORLD GENERATOR]: Post-initialization complete.");
        }

        public void Close()
        {
            if (!m_enabled) return;
            m_log.Info("[WORLD GENERATOR]: Shutting down...");
        }

        public void AddRegion(Scene scene)
        {
            if (!m_enabled) return;
            
            try
            {
                m_log.Info($"[WORLD GENERATOR]: Generating world for region {scene.RegionInfo.RegionName}...");
                
                // 1. Terrain generieren
                var heightmap = m_terrainGenerator.GenerateHeightmap(scene.RegionInfo.RegionSizeX, scene.RegionInfo.RegionSizeY);
                
                // 2. Biome-Karte generieren
                var biomeMap = m_biomeGenerator.GenerateBiomeMap(scene.RegionInfo.RegionSizeX, scene.RegionInfo.RegionSizeY, heightmap);
                
                // 3. Vegetation generieren
                m_forestGenerator.GenerateVegetation(scene, heightmap, biomeMap);
                
                // 4. Terrain texturieren
                TerrainPainter.PaintTerrain(scene, heightmap, biomeMap);
                
                m_log.Info($"[WORLD GENERATOR]: World generation completed for {scene.RegionInfo.RegionName}");
            }
            catch (Exception ex)
            {
                m_log.Error($"[WORLD GENERATOR]: Error generating world: {ex.Message}");
            }
        }

        public void RemoveRegion(Scene scene)
        {
            if (!m_enabled) return;
            m_log.Info($"[WORLD GENERATOR]: Removing region {scene.RegionInfo.RegionName}");
        }

        public void RegionLoaded(Scene scene)
        {
            if (!m_enabled) return;
            // Zusätzliche Initialisierung nach Laden der Region
        }
    }
}