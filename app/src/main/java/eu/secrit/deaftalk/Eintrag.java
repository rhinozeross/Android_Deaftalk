package eu.secrit.deaftalk;

public class Eintrag {

    //Eintrags Elemente
    private String eintrag;
    private boolean markiert;
    private boolean fromMeOrYou;

    public String getEintrag(){ return eintrag;}
    public void setEintrag(String eintrag){ this.eintrag = eintrag; }
    public boolean isMarkiert() { return markiert; }
    public void setMarkiert(boolean markiert) { this.markiert = markiert;}
    public boolean isFromMeOrYou() { return fromMeOrYou; }
    public void setFromMeOrYou(boolean fromMeOrYou) { this.fromMeOrYou = fromMeOrYou; }

    //Konstruktoren
    //Wird aufgerufen, sobald die Klasse mit "new" initialisiert wird
    public Eintrag(){
        this.setEintrag("Hier ist nichts drin");
        this.setMarkiert(false);
        this.setFromMeOrYou(true);
    }

    public String toString(){
        String retMarkiert = "";
        if (this.isMarkiert() == true){ retMarkiert = "X";}
        String retFromMeOrYou = "Gast";
        if (this.isFromMeOrYou() == true) {retFromMeOrYou = "Ich"; }

        return  retMarkiert + " " + retFromMeOrYou + ": "+ getEintrag();
    }
}
