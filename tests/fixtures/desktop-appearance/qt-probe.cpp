#include <QApplication>
#include <QStyleHints>
#include <QTimer>
#include <QWidget>
#include <QVBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <cstdio>
int main(int argc,char**argv){QApplication app(argc,argv);QWidget w;w.setWindowTitle("Wizard desktop mode verification — Qt");auto l=new QVBoxLayout(&w);l->addWidget(new QLabel("Qt desktop appearance"));l->addWidget(new QPushButton("System theme button"));w.resize(350,150);w.show();auto report=[&](){printf("scheme=%d window=%s text=%s\n",int(app.styleHints()->colorScheme()),qPrintable(app.palette().color(QPalette::Window).name()),qPrintable(app.palette().color(QPalette::WindowText).name()));fflush(stdout);};QObject::connect(app.styleHints(),&QStyleHints::colorSchemeChanged,&app,[&](auto){report();});QObject::connect(&app,&QApplication::paletteChanged,&app,[&](auto){report();});report();QTimer::singleShot(30000,&app,&QApplication::quit);return app.exec();}
