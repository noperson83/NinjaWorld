local AbilityMetadata = {
    Toss = {cost = 50, prerequisites = {}},
    Star = {cost = 100, prerequisites = {"Toss"}},
    Rain = {cost = 200, prerequisites = {"Star"}},
    Dragon = {cost = 300, prerequisites = {"Rain"}},
    Beast = {cost = 300, prerequisites = {"Rain"}},
}

return AbilityMetadata
