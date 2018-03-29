void main() {
  const mystery = 16;
  String retval = "";
  switch(true) {
      case (mystery < 2):
        retval = "1";
        break;
      case (mystery < 13):
        retval = "child";
        break;
      case (mystery < 21):
        retval = "teen";
        break;
      default:
        retval = "forever 21";
    }
  print(retval);
}