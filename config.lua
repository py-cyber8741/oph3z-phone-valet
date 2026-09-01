local resource = GetCurrentResourceName()

Config = {}

-- ==========================================
-- システム設定
-- ==========================================
Config.Locale = 'ja' -- 'ja' (日本語) または 'en' (英語)
Config.GarageSystem = 'ma' -- 'ma' (ma_garages) または 'qbx' (qbx_garages)

-- ==========================================
-- アプリ設定
-- ==========================================
Config.App = {
    id          = 'valet',
    label       = 'Valet App',
    developer   = 'no-name',
    description = 'valet app for oph3z-phone.',
    place       = 'grid',
    share       = true,

    icon = ('nui://%s/ui/icon.svg'):format(resource),
    ui   = ('nui://%s/ui/index.html'):format(resource),

    headerImage = ('nui://%s/ui/header.webp'):format(resource),
    swiperItems = {},
}