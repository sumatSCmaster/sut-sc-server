let extractRe = /\((?<key>.*)\)=\((?<value>.*)\)/;

export const errorMessageGenerator = (pgError) => {
  let msg = '';
  switch (pgError.code) {
    case '23505':
      let matches = pgError.detail.match(extractRe).groups;
      msg = `La referencia bancaria ya existe con el valor ${matches.value[1]}`;
      break;
  }
  return msg;
};

export const errorMessageExtractor = (error) => {
  if ('internalQuery' in error) {
    return error;
  } else {
    return error.message;
  }
};
