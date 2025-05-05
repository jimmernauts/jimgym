import { createClient } from '@supabase/supabase-js'
import { Ok, Error as GError, List } from "./gleam.mjs"
import { Some, None } from "hex:/gleam_stdlib/gleam/option.mjs"
import { ExerciseRecord } from "./common.gleam"

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_KEY
const supabase = createClient(supabaseUrl, supabaseKey)

export async function do_insert_exercise_records(records) {
    let exercise_records = []
    for (let record of records.toArray()) {
        console.log(record)
        exercise_records.push({
            date: record.date,
            name: record.name,
            ...(record.reps.constructor.name === "Some" ? { reps: record.reps[0] } : {}),
            ...(record.weight.constructor.name === "Some" ? { weight: record.weight[0] } : {}),
            ...(record.duration.constructor.name === "Some" ? { duration: record.duration[0] } : {}),
        })
    }
    const { data, error } = await supabase.from('exercise_records').insert(exercise_records)
    if (error) {
        console.error(error)
        return new GError(error)
    }
    return new Ok()
}

export async function do_retrieve_exercise_records() {
    const { data, error } = await supabase.from('exercise_records').select('*')
    if (error) {
        console.error(error)
        return new GError(error)
    }
    let return_records = []
    data.map((record) => {
        const new_record = new ExerciseRecord(
            record.date,
            record.name,
            (record.reps ? new Some(record.reps) : new None),
            (record.weight ? new Some(record.weight) : new None),
            (record.duration ? new Some(record.duration) : new None),
        )
        return_records.push(new_record)
    })
    return new Ok(List.fromArray(return_records))
}

export async function do_retrieve_days_with_past_sessions() {
    const { data, error } = await supabase.from('exercise_records').select('date').distinct()
    if (error) {
        console.error(error)
        return new GError(error)
    }
    let return_records = []
    for (let record of data) {
        return_records.push(record.date)
    }
    return new Ok(List.fromArray(return_records))
}