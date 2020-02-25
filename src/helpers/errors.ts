

let extractRe = /\((?<key>.*)\)=\((?<value>.*)\)/

export const errorMessageGenerator = (pgError) => {
    let msg = '';
    switch(pgError.code){
        case "23505":
            let matches = pgError.detail.match(extractRe).groups;
            msg = `La llave ${matches.key} ya existe con el valor ${matches.value}`;
            break;
    }
    return msg;
} 