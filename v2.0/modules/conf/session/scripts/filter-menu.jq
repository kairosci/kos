($policy[0].removeMenus) as $remove
| (.items // .)
| with_entries(select(.key as $key | all($remove[]; . as $prefix | ($key != $prefix and ($key | startswith($prefix + ".") | not)))))
