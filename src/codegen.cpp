#include "node.h"
#include <stack>
#include <typeinfo>
#include <llvm/IR/Module.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/Type.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/CallingConv.h>
#include <llvm/IR/IRPrintingPasses.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Bitstream/BitstreamReader.h>
#include <llvm/Bitstream/BitstreamWriter.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/MCJIT.h>
#include <llvm/ExecutionEngine/GenericValue.h>
#include <llvm/Support/raw_ostream.h>
#include "parser.hpp"

using namespace std;
using namespace llvm;

static LLVMContext Context;
static IRBuilder<> Builder(TheContext);
static std::unique_ptr<Module> Module;
static std::map<std::string, Value *> Variables;

void error(std::string error, std::string message){
	cerr <<	error << " on line"<< lineno <<": " message ;
}

Type* typeOf(std::string type){
	switch(type){
		case "INT": return Type::getIntTy(Context);
		case "FLOAT": return Type::getDoubleTy(Context);
		default: return nullptr;
	}
}
/* -- Code Generation -- */

Value* Integer::codeGen()
{
	return ConstantInt::get(Context, value, true);
}

Value* Double::codeGen()
{
	return ConstantFP::get(Context, value);
}

Value* BinaryOp::codeGen()
{
	Value* l = lhs.codeGen();
	Value* r = rhs.codeGen(;
	switch(op){
		case "+": return Builder.CreateFAdd(l, r);
		case "-": return Builder.CreateFSub(l, r);
		case "*": return Builder.CreateFMul(l, r);
		case "/": return Builder.CreateFDiv(l, r);
		default: return error("SyntaxError", "Undefined operator "+ op); 
	}
}

Value* Identifier::codeGen()
{
	Value* value = Variables[name];
	if(!value){
		return error("SyntaxError", "Undefined Variable" + name)
	}
	
	if(function->arg_size() != arguments.size()){
		return error("SyntaxError", "Expected "+ function->arg_size()+ "arguments, but got " + arguments.size());
	}

	std::vector<Value*> args;
	for (int i = 0; i < arguments.size(); i++){
		args.push_back(arguments[i]->codeGen());
	}
	return Builder->CreateCall(function, args);
}

Value* FunctionCall::codeGen()
{
	Function* function = Module->getFunction(id.name);
	if (!function) {
		return error("SyntaxError", "Function is undefined: "+ id.name);
	}
	std::vector<Value*> args;
	ExpressionList::const_iterator it;
	for (it = arguments.begin(); it != arguments.end(); it++) {
		args.push_back((**it).codeGen(context));
	}
	CallInst *call = CallInst::Create(function, args, "", context.currentBlock());
	return call;
}

Value* FunctionDeclaration::codeGen()
{
	vector<Type*> argTypes;
	VariableList::const_iterator it;
	for (it = arguments.begin(); it != arguments.end(); it++) {
		argTypes.push_back(typeOf((**it).type));
	}
	FunctionType *ftype = FunctionType::get(typeOf(type), makeArrayRef(argTypes), false);
	Function *function = Function::Create(ftype, GlobalValue::InternalLinkage, id.name.c_str(), context.module);
	BasicBlock *bblock = BasicBlock::Create(MyContext, "entry", function, 0);

	context.pushBlock(bblock);

	Function::arg_iterator argsValues = function->arg_begin();
    Value* argumentValue;

	for (it = arguments.begin(); it != arguments.end(); it++) {
		(**it).codeGen(context);
		
		argumentValue = &*argsValues++;
		argumentValue->setName((*it)->id.name.c_str());
		StoreInst *inst = new StoreInst(argumentValue, context.locals()[(*it)->id.name], false, bblock);
	}
	
	block.codeGen(context);
	ReturnInst::Create(MyContext, context.getCurrentReturnValue(), bblock);

	context.popBlock();
	return function;
}
