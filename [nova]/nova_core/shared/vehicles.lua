Shared = Shared or {}

-- qb-style vehicle list used by dealerships, garages and the phone for nice labels.
-- Vehicles that aren't listed still work everywhere; they just show their spawn name.
Shared.Vehicles = {
    -- Compacts
    blista = { name = 'Blista', brand = 'Dinka', price = 18000, category = 'compacts', shop = 'pdm' },
    -- Sedans
    asea = { name = 'Asea', brand = 'Declasse', price = 4000, category = 'sedans', shop = 'pdm' },
    sultan = { name = 'Sultan', brand = 'Karin', price = 45000, category = 'sedans', shop = 'pdm' },
    sentinel = { name = 'Sentinel', brand = 'Ubermacht', price = 52000, category = 'sedans', shop = 'pdm' },
    -- Sports
    elegy2 = { name = 'Elegy RH8', brand = 'Annis', price = 95000, category = 'sports', shop = 'pdm' },
    kuruma = { name = 'Kuruma', brand = 'Karin', price = 110000, category = 'sports', shop = 'pdm' },
    comet2 = { name = 'Comet', brand = 'Pfister', price = 135000, category = 'sports', shop = 'pdm' },
    -- Super
    zentorno = { name = 'Zentorno', brand = 'Pegassi', price = 450000, category = 'super', shop = 'pdm' },
    adder = { name = 'Adder', brand = 'Truffade', price = 650000, category = 'super', shop = 'pdm' },
    -- SUVs / trucks
    baller = { name = 'Baller', brand = 'Gallivanter', price = 85000, category = 'suvs', shop = 'pdm' },
    bison = { name = 'Bison', brand = 'Bravado', price = 60000, category = 'vans', shop = 'pdm' },
    -- Motorcycles
    sanchez = { name = 'Sanchez', brand = 'Maibatsu', price = 14000, category = 'motorcycles', shop = 'pdm' },
    bati = { name = 'Bati 801', brand = 'Pegassi', price = 28000, category = 'motorcycles', shop = 'pdm' },
}

for model, vehicle in pairs(Shared.Vehicles) do
    vehicle.model = model
    vehicle.hash = GetHashKey(model)
end
