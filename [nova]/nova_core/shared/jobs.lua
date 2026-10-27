Shared = Shared or {}

-- Grades use numeric keys starting at 0. The qb bridge converts them to qb's
-- string keys ('0', '1', ...) for legacy scripts automatically.
Shared.Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Freelancer', payment = 10 },
        },
    },
    police = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Recruit', payment = 50 },
            [1] = { name = 'Officer', payment = 75 },
            [2] = { name = 'Sergeant', payment = 100 },
            [3] = { name = 'Lieutenant', payment = 125 },
            [4] = { name = 'Chief', payment = 150, isboss = true },
        },
    },
    ambulance = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Recruit', payment = 50 },
            [1] = { name = 'Paramedic', payment = 75 },
            [2] = { name = 'Doctor', payment = 100 },
            [3] = { name = 'Surgeon', payment = 125 },
            [4] = { name = 'Chief', payment = 150, isboss = true },
        },
    },
    mechanic = {
        label = 'Mechanic',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Recruit', payment = 50 },
            [1] = { name = 'Novice', payment = 75 },
            [2] = { name = 'Experienced', payment = 100 },
            [3] = { name = 'Advanced', payment = 125 },
            [4] = { name = 'Manager', payment = 150, isboss = true },
        },
    },
    taxi = {
        label = 'Taxi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Recruit', payment = 50 },
            [1] = { name = 'Driver', payment = 75 },
            [2] = { name = 'Event Driver', payment = 100 },
            [3] = { name = 'Sales', payment = 125 },
            [4] = { name = 'Manager', payment = 150, isboss = true },
        },
    },
}
