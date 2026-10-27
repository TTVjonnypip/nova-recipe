Config = {}

-- Timing (real-world time, keeps progressing while the player is offline)
Config.DayLengthSeconds   = 86400 -- seconds in one "pregnancy day" (86400 = 1 real day; lower it for testing)
Config.PregnancyDays      = 14    -- total days from start to due date
Config.TestDetectAfterDays = 1    -- a pregnancy test reads positive after this many days

-- Who counts as medical staff: job name = minimum grade
Config.MedicJobs = {
    ambulance = 0,
}
Config.RequireOnDuty   = true
Config.MaxDistance     = 3.0   -- medic must be this close to the patient
Config.AdminGroup      = 'group.admin'

-- Delivery
Config.AllowEarlyDelivery = false            -- if false, /deliver only works once the due date is reached
Config.BirthItem          = 'birth_certificate' -- set to false to give no item

-- Items
Config.TestItem = 'pregnancy_test'

-- Symptoms
Config.Symptoms = {
    enabled        = true,
    interval       = 6 * 60 * 1000, -- ms between symptom rolls
    nauseaChance   = 35,            -- % per roll, trimester 1
    cravingChance  = 40,            -- % per roll, trimester 2
    backPainChance = 40,            -- % per roll, trimester 3
    cravings = { 'pickles', 'ice cream', 'a burger', 'donuts', 'tacos', 'spicy chips' },
}

-- Third trimester movement
Config.LateMoveRate   = 0.85                         -- 1.0 = normal speed
Config.LateWalkstyle  = 'move_characters@jimmy@slow@' -- set to false to leave walkstyle alone
Config.DisableSprintLate = true
